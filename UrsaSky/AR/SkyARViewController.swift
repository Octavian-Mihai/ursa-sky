import SwiftUI
import SceneKit
import ARKit
import AVFoundation
import UIKit
import simd

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
    private var lastAimedSky: SkyAim?
    private var stillSeconds: TimeInterval = 0
    private var lastStillCheck = Date()
    private var pausedForStill = false
    private var pausedForBackground = false
    private var uiTimer: Timer?
    private var labelStars: [Star] = []
    private var overlayConstellations: [Constellation] = []
    var starHRIndex: [Int] = []
    private var tapTargets: [(star: Star, direction: SIMD3<Double>)] = []

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
        // Opening the info sheet republishes AppState. Rebuilding ~1k cylinders
        // on that path stalled the main thread (gesture-gate timeout) and the
        // process was SIGKILL'd.
        if app.infoSheetOpen { return }
        let jd = app.clock.julianDay()
        let locChanged = abs(loc.latitude - lastLat) > 0.0005 || abs(loc.longitude - lastLon) > 0.0005
        let magChanged = abs(app.magLimit - lastMagLimit) > 0.05
        let timeChanged = abs(jd - lastJD) > (2.0 / 1440.0)
        let aimChanged = lastAimedSky != app.aimedSky
        if !locChanged, !magChanged, !timeChanged, !aimChanged {
            return
        }
        lastMagLimit = app.magLimit
        lastJD = jd
        lastLat = loc.latitude
        lastLon = loc.longitude
        lastAimedSky = app.aimedSky
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
        let (starNode, hrs, dirs) = SkySphereBuilder.starNode(
            stars: stars, magLimit: app.magLimit, jd: jd,
            latitude: loc.latitude, longitude: loc.longitude
        )
        starHRIndex = hrs
        tapTargets = zip(hrs, dirs).compactMap { hr, dir in
            byHR[hr].map { ($0, dir) }
        }
        // Bright named stars only, capped later — Polaris is pinned in regardless
        // of magnitude or the density prefix so the North Star always has a name.
        labelStars = stars.filter { $0.commonName != nil && $0.mag <= min(2.4, app.magLimit) }
        if let polaris = stars.first(where: { $0.isPolaris }) ?? app.catalog.star(hr: Star.polarisHR) {
            labelStars.removeAll { $0.isPolaris }
            labelStars.insert(polaris, at: 0)
        }
        overlayConstellations = app.catalog.allConstellations()
        skyRoot.addChildNode(starNode)
        let lines = app.catalog.lines()
        skyRoot.addChildNode(SkySphereBuilder.lineNode(
            lines: lines,
            starsByHR: byHR,
            jd: jd,
            latitude: loc.latitude,
            longitude: loc.longitude,
            highlightIAU: app.aimedConstellationIAU
        ))
        addAimedStarMarker(jd: jd, loc: loc)

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
        let bounds = view.bounds
        if overlayConstellations.isEmpty {
            overlayConstellations = app.catalog.allConstellations()
        }
        addConstellationNameLabels(jd: jd, loc: loc, bounds: bounds)
        addAimOverlay(jd: jd, loc: loc, bounds: bounds)
        for star in labelStars.prefix(40) {
            if case .star(let hr) = app.aimedSky, star.hr == hr { continue }
            let h = HorizontalConvert.altAz(equatorialJ2000: star.equatorial, jd: jd, latitude: loc.latitude, longitudeEast: loc.longitude)
            // Polaris stays labeled even when it sits near the horizon.
            guard h.alt > (star.isPolaris ? -0.6 : 8) else { continue }
            let d = HorizontalConvert.sceneDirection(altAz: h) * SkySphereBuilder.radius
            let p = SCNVector3(d.x, d.y, d.z)
            let projected = sceneView.projectPoint(p)
            let px = CGFloat(projected.x)
            let py = CGFloat(projected.y)
            let pz = CGFloat(projected.z)
            if pz < 0 || pz > 1 { continue }
            if px < 20 || py < 40 || px > bounds.width - 20 { continue }
            let lab = UILabel(frame: CGRect(x: px - 40, y: py - 18, width: 80, height: 16))
            lab.text = star.isPolaris ? "Polaris" : star.displayName
            lab.textColor = UIColor(white: 0.92, alpha: 0.9)
            lab.font = .systemFont(ofSize: 10, weight: .medium)
            lab.textAlignment = .center
            lab.layer.shadowColor = UIColor.black.cgColor
            lab.layer.shadowRadius = 2
            lab.layer.shadowOpacity = 1
            overlayHost.addSubview(lab)
        }
    }

    private func addConstellationNameLabels(jd: Double, loc: ObserverLocation, bounds: CGRect) {
        let cx = bounds.midX
        let cy = bounds.midY
        var names: [(text: String, x: CGFloat, y: CGFloat, dist2: CGFloat)] = []
        for con in overlayConstellations {
            let h = HorizontalConvert.altAz(
                equatorialJ2000: con.equatorial,
                jd: jd,
                latitude: loc.latitude,
                longitudeEast: loc.longitude
            )
            guard h.alt >= 12 else { continue }
            if case .constellation(let iau) = app?.aimedSky, iau.caseInsensitiveCompare(con.iau) == .orderedSame {
                continue
            }
            let d = HorizontalConvert.sceneDirection(altAz: h) * SkySphereBuilder.radius
            let projected = sceneView.projectPoint(SCNVector3(d.x, d.y, d.z))
            let px = CGFloat(projected.x)
            let py = CGFloat(projected.y)
            let pz = CGFloat(projected.z)
            if pz < 0 || pz > 1 { continue }
            if px < 28 || py < 48 || px > bounds.width - 28 || py > bounds.height - 36 { continue }
            let dx = px - cx
            let dy = py - cy
            names.append((con.name, px, py, dx * dx + dy * dy))
        }
        names.sort { $0.dist2 < $1.dist2 }
        for item in names.prefix(15) {
            let lab = UILabel()
            lab.text = item.text
            lab.textColor = UIColor(white: 0.94, alpha: 0.92)
            lab.font = .systemFont(ofSize: 13, weight: .semibold)
            lab.textAlignment = .center
            lab.layer.shadowColor = UIColor.black.cgColor
            lab.layer.shadowRadius = 3
            lab.layer.shadowOpacity = 1
            lab.sizeToFit()
            var f = lab.frame
            f.size.width += 10
            f.size.height += 2
            f.origin = CGPoint(x: item.x - f.width / 2, y: item.y - f.height / 2)
            lab.frame = f
            overlayHost.addSubview(lab)
        }
    }

    private func addAimedStarMarker(jd: Double, loc: ObserverLocation) {
        guard let app, let target = app.aimedTarget() else { return }
        let h = HorizontalConvert.altAz(
            equatorialJ2000: target.equatorial,
            jd: jd,
            latitude: loc.latitude,
            longitudeEast: loc.longitude
        )
        guard h.alt > -0.6 else { return }
        let size: CGFloat = {
            if case .star = app.aimedSky { return 0.16 }
            return 0.11
        }()
        skyRoot.addChildNode(SkySphereBuilder.markerNode(
            named: "aim-target",
            altAz: h,
            color: SkySphereBuilder.aimHighlight,
            size: size
        ))
    }

    private func addAimOverlay(jd: Double, loc: ObserverLocation, bounds: CGRect) {
        guard let app, let target = app.aimedTarget() else { return }
        let gold = SkySphereBuilder.aimHighlight
        let h = HorizontalConvert.altAz(
            equatorialJ2000: target.equatorial,
            jd: jd,
            latitude: loc.latitude,
            longitudeEast: loc.longitude
        )
        let d = HorizontalConvert.sceneDirection(altAz: h) * SkySphereBuilder.radius
        let projected = sceneView.projectPoint(SCNVector3(d.x, d.y, d.z))
        let px = CGFloat(projected.x)
        let py = CGFloat(projected.y)
        let pz = CGFloat(projected.z)
        let pad: CGFloat = 28
        let onScreen = pz >= 0 && pz <= 1
            && px >= pad && px <= bounds.width - pad
            && py >= pad + 36 && py <= bounds.height - pad
        if onScreen {
            let ring = UIView(frame: CGRect(x: px - 20, y: py - 20, width: 40, height: 40))
            ring.layer.cornerRadius = 20
            ring.layer.borderWidth = 2
            ring.layer.borderColor = gold.cgColor
            ring.backgroundColor = .clear
            overlayHost.addSubview(ring)
            let dot = UIView(frame: CGRect(x: px - 3, y: py - 3, width: 6, height: 6))
            dot.layer.cornerRadius = 3
            dot.backgroundColor = gold
            overlayHost.addSubview(dot)
            let lab = UILabel()
            lab.text = target.name
            lab.textColor = gold
            lab.font = .systemFont(ofSize: 13, weight: .bold)
            lab.textAlignment = .center
            lab.layer.shadowColor = UIColor.black.cgColor
            lab.layer.shadowRadius = 3
            lab.layer.shadowOpacity = 1
            lab.sizeToFit()
            var f = lab.frame
            f.size.width += 12
            f.origin = CGPoint(x: px - f.width / 2, y: py + 22)
            lab.frame = f
            overlayHost.addSubview(lab)
            return
        }
        var dx = px - bounds.midX
        var dy = py - bounds.midY
        if pz < 0 || pz > 1 {
            dx = -dx
            dy = -dy
        }
        let (edge, angle) = edgeChevron(dx: dx, dy: dy, in: bounds)
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = gold
        chevron.contentMode = .scaleAspectFit
        chevron.frame = CGRect(x: edge.x - 14, y: edge.y - 14, width: 28, height: 28)
        chevron.transform = CGAffineTransform(rotationAngle: angle)
        chevron.layer.shadowColor = UIColor.black.cgColor
        chevron.layer.shadowRadius = 3
        chevron.layer.shadowOpacity = 1
        overlayHost.addSubview(chevron)
    }

    private func edgeChevron(dx: CGFloat, dy: CGFloat, in bounds: CGRect) -> (CGPoint, CGFloat) {
        let inset = bounds.insetBy(dx: 32, dy: 110)
        let origin = CGPoint(x: inset.midX, y: inset.midY)
        var vx = dx
        var vy = dy
        let len = hypot(vx, vy)
        if len < 1e-4 {
            vx = 0
            vy = -1
        } else {
            vx /= len
            vy /= len
        }
        var t = CGFloat.greatestFiniteMagnitude
        if vx > 1e-6 { t = min(t, (inset.maxX - origin.x) / vx) }
        if vx < -1e-6 { t = min(t, (inset.minX - origin.x) / vx) }
        if vy > 1e-6 { t = min(t, (inset.maxY - origin.y) / vy) }
        if vy < -1e-6 { t = min(t, (inset.minY - origin.y) / vy) }
        if !t.isFinite { t = 0 }
        return (CGPoint(x: origin.x + vx * t, y: origin.y + vy * t), atan2(vy, vx))
    }

    @objc private func handleTap(_ gr: UITapGestureRecognizer) {
        if pausedForStill {
            pausedForStill = false
            stillSeconds = 0
            startAR()
        }
        guard let app else { return }
        let pt = gr.location(in: sceneView)
        if let star = HitTester.nearestCached(
            tap: pt, in: sceneView, targets: tapTargets
        ) {
            app.showStar(star)
        } else {
            app.clearSkyAim()
        }
    }
}
