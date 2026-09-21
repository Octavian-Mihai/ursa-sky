import Foundation
import CoreMotion
import SceneKit
import simd
import Combine

final class AttitudeFusion: ObservableObject {
    let motion = CMMotionManager()
    @Published var magneticAccuracy: CMMagneticFieldCalibrationAccuracy = .uncalibrated
    @Published var gyroMagnitude: Double = 1
    @Published var usingTrueNorth = true

    private var lastQuat: simd_quatd?
    private let queue = OperationQueue()

    func start() {
        guard motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 60.0
        let frames = CMMotionManager.availableAttitudeReferenceFrames()
        let ref: CMAttitudeReferenceFrame
        if frames.contains(.xTrueNorthZVertical) {
            ref = .xTrueNorthZVertical
            usingTrueNorth = true
        } else {
            ref = .xMagneticNorthZVertical
            usingTrueNorth = false
        }
        motion.startDeviceMotionUpdates(using: ref, to: queue) { [weak self] data, _ in
            guard let self, let data else { return }
            let acc = data.magneticField.accuracy
            let gx = data.rotationRate.x
            let gy = data.rotationRate.y
            let gz = data.rotationRate.z
            let mag = sqrt(gx * gx + gy * gy + gz * gz)
            DispatchQueue.main.async {
                self.magneticAccuracy = acc
                self.gyroMagnitude = mag
            }
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
    }

    /// Camera orientation in SceneKit for a Y-up, −Z-north world built from alt/az.
    func cameraOrientationSlerped() -> SCNQuaternion? {
        guard let att = motion.deviceMotion?.attitude else { return nil }
        let q = att.quaternion
        // CoreMotion device→world (x north, y east, z up) → SceneKit camera.
        var dest = simd_quatd(ix: q.y, iy: q.x, iz: -q.z, r: q.w)
        dest = simd_normalize(dest)
        if let last = lastQuat {
            dest = simd_slerp(last, dest, 0.25)
        }
        lastQuat = dest
        return QuatMath.sceneKit(dest)
    }
}
