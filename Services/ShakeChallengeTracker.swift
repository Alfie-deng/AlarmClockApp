import Foundation

struct ShakeChallengeTracker {
    let requiredCount: Int
    let threshold: Double
    let cooldown: TimeInterval
    
    private(set) var count: Int = 0
    private var lastAcceptedAt: Date?
    
    init(requiredCount: Int = 20, threshold: Double = 2.2, cooldown: TimeInterval = 0.18) {
        self.requiredCount = requiredCount
        self.threshold = threshold
        self.cooldown = cooldown
    }
    
    var isComplete: Bool {
        count >= requiredCount
    }
    
    var progress: Double {
        guard requiredCount > 0 else { return 1 }
        return min(1, Double(count) / Double(requiredCount))
    }
    
    mutating func recordAcceleration(x: Double, y: Double, z: Double, at date: Date = Date()) -> Bool {
        guard !isComplete else { return false }
        let magnitude = sqrt(x * x + y * y + z * z)
        guard magnitude >= threshold else { return false }
        if let lastAcceptedAt, date.timeIntervalSince(lastAcceptedAt) < cooldown {
            return false
        }
        
        count += 1
        lastAcceptedAt = date
        return true
    }
    
    mutating func recordMockShake(at date: Date = Date()) -> Bool {
        recordAcceleration(x: threshold, y: 0, z: 0, at: date)
    }
}
