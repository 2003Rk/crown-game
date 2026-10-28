import CoreMotion
import UIKit

/// Optional tilt steering using the device's gravity vector. Reading device motion
/// for gravity needs no permission prompt and transmits nothing.
@MainActor
final class TiltInput {
    /// Tilt below this (in g) is ignored so the catcher doesn't drift when held flat-ish.
    nonisolated static let deadZone = 0.03
    /// Tilt at which the catcher reaches full speed.
    nonisolated static let fullTilt = 0.35

    /// Whether this device has the sensors needed for tilt steering.
    static let isSupported = CMMotionManager().isDeviceMotionAvailable

    private let manager = CMMotionManager()

    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    func start() {
        guard isAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates()
    }

    func stop() {
        guard manager.isDeviceMotionActive else { return }
        manager.stopDeviceMotionUpdates()
    }

    /// Horizontal tilt in screen space, -1 (left) ... 1 (right).
    func horizontalTilt(for orientation: UIInterfaceOrientation) -> Double {
        guard let gravity = manager.deviceMotion?.gravity else { return 0 }
        let raw: Double
        switch orientation {
        case .landscapeLeft: raw = gravity.y
        case .landscapeRight: raw = -gravity.y
        case .portraitUpsideDown: raw = -gravity.x
        default: raw = gravity.x
        }
        return Self.normalizedTilt(raw)
    }

    nonisolated static func normalizedTilt(_ raw: Double) -> Double {
        guard abs(raw) > deadZone else { return 0 }
        let sign: Double = raw > 0 ? 1 : -1
        return sign * min(1, (abs(raw) - deadZone) / (fullTilt - deadZone))
    }
}
