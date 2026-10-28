import Foundation

enum WakeSessionStats {
    static func completedSessions(_ sessions: [WakeSession], including current: WakeSession? = nil) -> [WakeSession] {
        var completed = sessions.filter { !$0.emergencyClosed }
        if let current, !current.emergencyClosed, !completed.contains(where: { $0.id == current.id }) {
            completed.append(current)
        }
        return completed
    }
    
    static func currentStreak(sessions: [WakeSession], endingOn date: Date, calendar: Calendar = .current) -> Int {
        streakEnding(on: date, sessions: sessions, calendar: calendar)
    }
    
    static func bestStreak(sessions: [WakeSession], calendar: Calendar = .current) -> Int {
        let days = Set(sessions.map { calendar.startOfDay(for: $0.completedAt) }).sorted()
        guard !days.isEmpty else { return 0 }
        
        var best = 1
        var current = 1
        for index in days.indices.dropFirst() {
            let previous = days[days.index(before: index)]
            let day = days[index]
            if calendar.dateComponents([.day], from: previous, to: day).day == 1 {
                current += 1
            } else {
                current = 1
            }
            best = max(best, current)
        }
        return best
    }
    
    private static func streakEnding(on date: Date, sessions: [WakeSession], calendar: Calendar) -> Int {
        let days = Set(sessions.map { calendar.startOfDay(for: $0.completedAt) })
        var count = 0
        var cursor = calendar.startOfDay(for: date)
        // 今天还没起床打卡时，从昨天往回数，别一早就显示连续 0 天。
        if !days.contains(cursor) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        while days.contains(cursor) {
            count += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return count
    }
}
