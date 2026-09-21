import SwiftUI
import SceneKit
import ARKit
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
    private var sceneView: ARSCNView!
    private var skyRoot = SCNNode()
    private var overlayHost: UIView!
    private var lastRebuild: Date = .distantPast
    private var lastMagLimit: Double = -1
    private var lastJDBucket: Int = 0
    private var stillSeconds: TimeInterval = 0
    private var lastStillCheck = Date()
    private var pausedForStill = false
    var starHRIndex: [Int] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let ar = ARSCNView(frame: view.bounds)
        ar.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        ar.delegate = self
        ar.autoenablesDefaultLighting = false
        ar.rendersContinuously = true
        ar.scene = SCNScene()
        ar.scene.rootNode.addChildNode(skyRoot)
        sceneView = ar
        view.addSubview(ar)

        overlayHost = UIView(frame: view.bounds)
        overlayHost.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlayHost.isUserInteractionEnabled = false
        view.addSubview(overlayHost)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.delegate = self
        ar.addGestureRecognizer(tap)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startAR()
        app?.attitude.start()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
        app?.attitude.stop()
    }

    func startAR() {
        guard AROrientationTrackingConfiguration.isSupported else { return }
        let cfg = AROrientationTrackingConfiguration()
        sceneView.session.run(cfg, options: [.resetTracking])
        pausedForStill = false
    }

    func applyPauseState() {
        guard let app else { return }
        if app.arPaused {
            sceneView.session.pause()
            sceneView.rendersContinuously = false
        } else if pausedForStill == false {
            sceneView.rendersContinuously = true
        }
    }

    func rebuildIfNeeded() {
        guard let app, let loc = app.location.current else { return }
        let jd = app.clock.julianDay()
        let bucket = Int(jd * 48) // ~30 min
        if abs(app.magLimit - lastMagLimit) < 0.05, bucket == lastJDBucket, Date().timeIntervalSince(lastRebuild) < 20 {
            return
        }
        lastMagLimit = app.magLimit
        lastJDBucket = bucket
        lastRebuild = Date()
        rebuildSky(jd: jd, loc: loc)
    }

    private func rebuildSky(jd: Double, loc: ObserverLocation) {
        guard let app else { return }
        skyRoot.childNodes.forEach { $0.removeFromParentNode() }
        let stars = app.catalog.stars(brighterThan: max(app.magLimit, 6.5))
        var byHR: [Int: Star] = [:]
        for s in stars { byHR[s.hr] = s }
        let (starNode, hrs) = SkySphereBuilder.starNode(
            stars: stars, magLimit: app.magLimit, jd: jd,
            latitude: loc.latitude, longitude: loc.longitude
        )
        starHRIndex = hrs
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
        if let q = app?.attitude.cameraOrientationSlerped() {
            sceneView.pointOfView?.orientation = q
        }
        updateLabels()
        checkStillPause()
    }

    private func checkStillPause() {
        guard let app else { return }
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
        if stillSeconds > 8, !pausedForStill {
            pausedForStill = true
            sceneView.session.pause()
        }
    }

    private func updateLabels() {
        overlayHost.subviews.forEach { $0.removeFromSuperview() }
        guard let app, let loc = app.location.current, let pov = sceneView.pointOfView else { return }
        let jd = app.clock.julianDay()
        let named = app.catalog.stars(brighterThan: min(2.4, app.magLimit)).filter { $0.commonName != nil }
        for star in named.prefix(40) {
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
        _ = pov
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
