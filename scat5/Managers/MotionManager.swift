import Foundation
import CoreMotion

@MainActor
@Observable
class MotionManager {
    private let motionManager = CMMotionManager()
    
    var pitch: Double = 0
    var roll: Double = 0
    var yaw: Double = 0
    
    var isRunning: Bool = false
    
    func startUpdates() {
        guard !isRunning, motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (data, error) in
            guard let self, let motion = data else { return }
            self.pitch = motion.attitude.pitch
            self.roll = motion.attitude.roll
            self.yaw = motion.attitude.yaw
        }
        isRunning = true
    }
    
    func stopUpdates() {
        guard isRunning else { return }
        motionManager.stopDeviceMotionUpdates()
        isRunning = false
        pitch = 0
        roll = 0
        yaw = 0
    }
}