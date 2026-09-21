import SwiftUI
import SceneKit
import ARKit
import AVFoundation
import UIKit

struct SkyARRepresentable: UIViewControllerRepresentable {
    @ObservedObject var app: AppState

    func makeUIViewController(context: Context) -> SkyARViewController {
        let vc = SkyARViewController()
        vc.app = app
        return vc
    }

    func updateUIViewController(_ vc: SkyARViewController, context: Context) {
        vc.app = app
        vc.rebuildIfNeeded()
        vc.applyPauseState()
    }
}

final class SkyARViewController: UIViewController, ARSCNViewDelegate, UIGestureRecognizerDelegate {
    var app: AppState?
    private var sceneView: SCNView!
    private var arView: ARSCNView?
    private var usingAR = false
    private var fallbackCamera: SCNNode?
    private var skyRoot = SCNNode()
    private var overlayHost: UIView!
    private var lastRebuild: Date = .distantPast
    private var lastMagLimit: Double = -1
    private var lastJD: Double = 0
    private var lastLat: Double = 999
    private var lastLon: Double = 999
    private var stillSeconds: TimeInterval = 0
    private var lastStillCheck = Date()
    private var pausedForStill = false
    private var pausedForBackground = false
    private var uiTimer: Timer?
    private var labelStars: [Star] = []
    var starHRIndex: [Int] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let scene = SCNScene()
        scene.rootNode.addChildNode(skyRoot)

        if Self.canRunAR {
            let ar = ARSCNView(frame: view.bounds)
            ar.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            ar.delegate = self
            ar.autoenablesDefaultLighting = false
            ar.rendersContinuously = true
            ar.scene = scene
            sceneView = ar
            arView = ar
            view.addSubview(ar)
        } else {
            let scn = SCNView(frame: view.bounds)
            scn.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            scn.delegate = self
            scn.autoenablesDefaultLighting = false
            scn.rendersContinuously = true
            scn.scene = scene
            scn.backgroundColor = .black
            scn.allowsCameraControl = true
            sceneView = scn
            view.addSubview(scn)
            installFallbackCamera()
        }

        overlayHost = UIView(frame: view.bounds)
        overlayHost.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlayHost.isUserInteractionEnabled = false
        view.addSubview(overlayHost)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.delegate = self
        sceneView.addGestureRecognizer(tap)
    }

    /// ARKit is unavailable in the simulator and when the user has denied the camera.
    private static var canRunAR: Bool {
        guard AROrientationTrackingConfiguration.isSupported else { return false }
        return AVCaptureDevice.authorizationStatus(for: .video) != .denied
    }

    private func installFallbackCamera() {
        let cam = SCNCamera()
        cam.fieldOfView = 65
        cam.zNear = 0.1
        cam.zFar = 40
        let node = SCNNode()
        node.camera = cam
        node.position = SCNVector3(0, 0, 0)
        // Look toward the zenith (+Y) so a static simulator view shows the overhead sky.
        node.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        sceneView.scene?.rootNode.addChildNode(node)
        sceneView.pointOfView = node
        fallbackCamera = node
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startAR()
        app?.attitude.start()
        rebuildIfNeeded()
        uiTimer?.invalidate()
        uiTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.updateLabels()
            self?.checkStillPause()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        uiTimer?.invalidate()
        uiTimer = nil
        arView?.session.pause()
        app?.attitude.stop()
    }

    func startAR() {
        pausedForStill = false
        sceneView.rendersContinuously = true
        guard let ar = arView, Self.canRunAR else { return }
        let cfg = AROrientationTrackingConfiguration()
        // Y up, Z south, X east — matches HorizontalConvert.sceneDirection.
        cfg.worldAlignment = .gravityAndHeading
        ar.session.run(cfg, options: [.resetTracking])
        usingAR = true
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        usingAR = false
        arView?.session.pause()
        if fallbackCamera == nil {
            installFallbackCamera()
        }
    }

    func applyPauseState() {
        guard let app else { return }
        if app.arPaused {
            arView?.session.pause()
            sceneView.rendersContinuously = false
            pausedForBackground = true
            return
        }
        if pausedForBackground {
            pausedForBackground = false
            pausedForStill = false
            stillSeconds = 0
            startAR()
        } else if pausedForStill == false {
            sceneView.rendersContinuously = true
        }
    }

    func rebuildIfNeeded() {
        guard let app, let loc = app.location.current else { return }
        let jd = app.clock.julianDay()
        let locChanged = abs(loc.latitude - lastLat) > 0.0005 || abs(loc.longitude - lastLon) > 0.0005
        let magChanged = abs(app.magLimit - lastMagLimit) > 0.05
        // ~2 minutes of sky motion, so the hour scrubber actually moves the sphere.
        let timeChanged = abs(jd - lastJD) > (2.0 / 1440.0)
        if !locChanged, !magChanged, !timeChanged, Date().timeIntervalSince(lastRebuild) < 25 {
            return
        }
        lastMagLimit = app.magLimit
        lastJD = jd
        lastLat = loc.latitude
        lastLon = loc.longitude
        lastRebuild = Date()
        rebuildSky(jd: jd, loc: loc)
    }

    private func rebuildSky(jd: Double, loc: ObserverLocation) {
        guard let app else { return }
        skyRoot.childNodes.forEach { $0.removeFromParentNode() }
        // Pull a bit fainter than the draw limit so stick-figure partners still exist.
        let stars = app.catalog.stars(brighterThan: max(app.magLimit, 7.0))
        var byHR: [Int: Star] = [:]
        for s in stars { byHR[s.hr] = s }
        let (starNode, hrs) = SkySphereBuilder.starNode(
            stars: stars, magLimit: app.magLimit, jd: jd,
            latitude: loc.latitude, longitude: loc.longitude
        )
        starHRIndex = hrs
        labelStars = stars.filter { $0.commonName != nil && $0.mag <= min(2.4, app.magLimit) }
        skyRoot.addChildNode(starNode)
        let lines = app.catalog.lines()
        skyRoot.addChildNode(SkySphereBuilder.lineNode(lines: lines, starsByHR: byHR, jd: jd, latitude: loc.latitude, longitude: loc.longitude))

        if let iss = app.iss.altAz(at: app.clock.now(), latitude: loc.latitude, longitudeEast: loc.longitude), iss.alt > 0 {
            skyRoot.addChildNode(SkySphereBuilder.markerNode(named: "iss", altAz: iss, color: .cyan, size: 0.12))
        }
        for shower in MeteorCatalog.shared.active(on: app.clock.now()) {
            let h = HorizontalConvert.altAz(equatorialJ2000: shower.equatorial, jd: jd, latitude: loc.latitude, longitudeEast: loc.longitude)
            if h.alt > 0 {
                skyRoot.addChildNode(SkySphereBuilder.markerNode(named: "radiant-\(shower.id)", altAz: h, color: .orange, size: 0.1))
            }
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        // Labels and still-pause run on a main-queue timer so UIKit/AppState
        // are never touched from SceneKit's render thread.
    }

    private func checkStillPause() {
        guard usingAR, let app else { return }
        let now = Date()
        let dt = now.timeIntervalSince(lastStillCheck)
        lastStillCheck = now
        if app.attitude.gyroMagnitude < 0.03 {
            stillSeconds += dt
        } else {
            stillSeconds = 0
            if pausedForStill {
                pausedForStill = false
                startAR()
            }
        }
        if stillSeconds > 8, !pausedForStill, !pausedForBackground {
            pausedForStill = true
            arView?.session.pause()
        }
    }

    private func updateLabels() {
        overlayHost.subviews.forEach { $0.removeFromSuperview() }
        guard let app, let loc = app.location.current, sceneView.pointOfView != nil else { return }
        let jd = app.clock.julianDay()
        for star in labelStars.prefix(40) {
            let h = HorizontalConvert.altAz(equatorialJ2000: star.equatorial, jd: jd, latitude: loc.latitude, longitudeEast: loc.longitude)
            guard h.alt > 8 else { continue }
            let d = HorizontalConvert.sceneDirection(altAz: h) * SkySphereBuilder.radius
            let p = SCNVector3(d.x, d.y, d.z)
            let projected = sceneView.projectPoint(p)
            let px = CGFloat(projected.x)
            let py = CGFloat(projected.y)
            let pz = CGFloat(projected.z)
            if pz < 0 || pz > 1 { continue }
            if px < 20 || py < 40 || px > view.bounds.width - 20 { continue }
            let lab = UILabel(frame: CGRect(x: px - 40, y: py - 18, width: 80, height: 16))
            lab.text = star.displayName
            lab.textColor = UIColor(white: 0.92, alpha: 0.9)
            lab.font = .systemFont(ofSize: 10, weight: .medium)
            lab.textAlignment = .center
            lab.layer.shadowColor = UIColor.black.cgColor
            lab.layer.shadowRadius = 2
            lab.layer.shadowOpacity = 1
            overlayHost.addSubview(lab)
        }
    }

    @objc private func handleTap(_ gr: UITapGestureRecognizer) {
        if pausedForStill {
            pausedForStill = false
            stillSeconds = 0
            startAR()
        }
        guard let app, let loc = app.location.current else { return }
        let pt = gr.location(in: sceneView)
        let stars = app.catalog.stars(brighterThan: app.magLimit)
        if let star = HitTester.nearestStar(
            tap: pt, in: sceneView, stars: stars,
            jd: app.clock.julianDay(), latitude: loc.latitude, longitude: loc.longitude,
            magLimit: app.magLimit
        ) {
            app.selectedStar = star
        }
    }
}
