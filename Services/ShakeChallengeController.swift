import CoreMotion
import Foundation

@MainActor
final class ShakeChallengeController: ObservableObject {
    @Published private(set) var count: Int = 0
    @Published private(set) var isMotionAvailable: Bool = true
    @Published private(set) var isRunning: Bool = false
    
    let requiredCount: Int
    private var tracker: ShakeChallengeTracker
    private let motionManager = CMMotionManager()
    private var onComplete: (() -> Void)?
    
    init(requiredCount: Int = 20) {
        self.requiredCount = requiredCount
        tracker = ShakeChallengeTracker(requiredCount: requiredCount)
    }
    
    var progress: Double {
        tracker.progress
    }
    
    func start(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        guard motionManager.isAccelerometerAvailable else {
            isMotionAvailable = false
            return
        }
        
        isMotionAvailable = true
        isRunning = true
        motionManager.accelerometerUpdateInterval = 0.05
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let acceleration = data?.acceleration else { return }
            Task { @MainActor in
                self.recordAcceleration(
                    x: acceleration.x,
                    y: acceleration.y,
                    z: acceleration.z
                )
            }
        }
    }
    
    func stop() {
        motionManager.stopAccelerometerUpdates()
        isRunning = false
    }
    
    func recordMockShake() {
        recordAccepted(tracker.recordMockShake())
    }
    
    private func recordAcceleration(x: Double, y: Double, z: Double) {
        recordAccepted(tracker.recordAcceleration(x: x, y: y, z: z))
    }
    
    private func recordAccepted(_ accepted: Bool) {
        guard accepted else { return }
        count = tracker.count
        if tracker.isComplete {
            stop()
            onComplete?()
        }
    }
}
