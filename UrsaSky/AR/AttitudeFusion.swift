import Foundation
import CoreMotion
import SceneKit
import simd
import Combine

final class AttitudeFusion: ObservableObject {
    let motion = CMMotionManager()
    /// Default is “unknown” so the figure-8 banner is not shown before the first sample.
    @Published var magneticAccuracy: CMMagneticFieldCalibrationAccuracy = .high
    @Published var usingTrueNorth = true
    @Published private(set) var hasMotionSample = false
    /// Gyro rate; not @Published — writing it at 60 Hz was spamming SwiftUI.
    private(set) var gyroMagnitude: Double = 1

    private var lastQuat: simd_quatd?
    private let queue = OperationQueue()
    private var started = false

    var compassNeedsCalibration: Bool {
        hasMotionSample && (magneticAccuracy == .low || magneticAccuracy == .uncalibrated)
    }

    func start() {
        guard motion.isDeviceMotionAvailable else { return }
        if started, motion.isDeviceMotionActive { return }
        started = true
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
                self.gyroMagnitude = mag
                if !self.hasMotionSample {
                    self.hasMotionSample = true
                }
                if acc != self.magneticAccuracy {
                    self.magneticAccuracy = acc
                }
            }
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        started = false
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
