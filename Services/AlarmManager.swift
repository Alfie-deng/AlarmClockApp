import Foundation
import UserNotifications
import Combine

@MainActor
class AlarmManager: ObservableObject {
    @Published var alarms: [Alarm] = []
    @Published var currentChallenge: ChallengeRecord?
    @Published var isShowingChallenge: Bool = false
    @Published var triggeredAlarm: Alarm?
    @Published var wakeSessions: [WakeSession] = []
    @Published var lastCompletedSession: WakeSession?
    @Published var isShowingSuccess: Bool = false
    @Published var notificationStatus: UNAuthorizationStatus = .notDetermined
    
    private let key = "savedAlarms"
    private let sessionsKey = "wakeSessions"
    
    init() {
        loadAlarms()
        loadWakeSessions()
        refreshNotificationStatus()
        requestPermission()
    }
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] _, _ in
            Task { @MainActor in
                self?.refreshNotificationStatus()
            }
        }
    }
    
    func refreshNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                self?.notificationStatus = settings.authorizationStatus
            }
        }
    }
    
    func addAlarm(_ alarm: Alarm) { alarms.append(alarm); saveAlarms(); scheduleNotification(for: alarm) }
    func updateAlarm(_ alarm: Alarm) {
        if let i = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[i] = alarm; saveAlarms(); cancelNotification(for: alarm)
            if alarm.isEnabled { scheduleNotification(for: alarm) }
        }
    }
    func deleteAlarm(_ alarm: Alarm) { alarms.removeAll { $0.id == alarm.id }; saveAlarms(); cancelNotification(for: alarm) }
    func toggleAlarm(_ alarm: Alarm) {
        if let i = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[i].isEnabled.toggle(); saveAlarms()
            if alarms[i].isEnabled { scheduleNotification(for: alarms[i]) }
            else { cancelNotification(for: alarms[i]) }
        }
    }
    
    private func saveAlarms() { if let d = try? JSONEncoder().encode(alarms) { UserDefaults.standard.set(d, forKey: key) } }
    private func loadAlarms() { if let d = UserDefaults.standard.data(forKey: key), let decoded = try? JSONDecoder().decode([Alarm].self, from: d) { alarms = decoded } }
    private func saveWakeSessions() { if let d = try? JSONEncoder().encode(wakeSessions) { UserDefaults.standard.set(d, forKey: sessionsKey) } }
    private func loadWakeSessions() { if let d = UserDefaults.standard.data(forKey: sessionsKey), let decoded = try? JSONDecoder().decode([WakeSession].self, from: d) { wakeSessions = decoded } }
    
    func scheduleNotification(for alarm: Alarm) {
        cancelNotification(for: alarm)
        guard alarm.isEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "起床挑战！"
        content.body = alarm.requiresChallenge ? "完成\(alarm.challengeType.rawValue)才能关闭" : "该起床了"
        content.sound = .default
        content.userInfo = ["alarmId": alarm.id.uuidString]
        
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: alarm.time)
        let weekdays = alarm.repeatWeekdays
        if weekdays.isEmpty {
            let next = alarm.nextOccurrence()
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: next)
            let request = UNNotificationRequest(
                identifier: alarm.id.uuidString,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            UNUserNotificationCenter.current().add(request)
            return
        }
        
        for weekday in weekdays {
            var components = DateComponents()
            components.weekday = weekday
            components.hour = timeComponents.hour
            components.minute = timeComponents.minute
            let identifier = notificationIdentifier(for: alarm, weekday: weekday)
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            )
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    func cancelNotification(for alarm: Alarm) {
        let identifiers = [alarm.id.uuidString] + (1...7).map { notificationIdentifier(for: alarm, weekday: $0) } + [snoozeIdentifier(for: alarm)]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    func pendingNotificationIdentifiers() async -> [String] {
        await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier).sorted()
    }
    
    func triggerChallenge(for alarm: Alarm) {
        triggeredAlarm = alarm
        currentChallenge = alarm.requiresChallenge ? makeChallengeRecord(for: alarm) : makeDismissOnlyRecord(for: alarm)
        isShowingChallenge = true
    }
    
    func triggerChallenge(alarmId: String?) {
        guard let alarmId,
              let uuid = UUID(uuidString: alarmId),
              let alarm = alarms.first(where: { $0.id == uuid }) else {
            if let fallback = alarms.filter(\.isEnabled).sorted(by: { $0.nextOccurrence() < $1.nextOccurrence() }).first {
                triggerChallenge(for: fallback)
            }
            return
        }
        triggerChallenge(for: alarm)
    }
    
    func completeChallenge() {
        guard let challenge = currentChallenge else {
            isShowingChallenge = false
            return
        }
        
        let completedAt = Date()
        let session = WakeSession(
            alarmId: triggeredAlarm?.id ?? challenge.alarmId,
            alarmLabel: triggeredAlarm?.label ?? "起床",
            challengeType: challenge.type,
            mathDifficulty: challenge.difficulty,
            startedAt: challenge.startedAt,
            completedAt: completedAt,
            durationSeconds: max(1, Int(completedAt.timeIntervalSince(challenge.startedAt))),
            mood: nil,
            note: "",
            emergencyClosed: false
        )
        wakeSessions.insert(session, at: 0)
        saveWakeSessions()
        lastCompletedSession = session
        isShowingChallenge = false
        triggeredAlarm = nil
        currentChallenge = nil
        isShowingSuccess = true
    }
    
    func snooze() {
        if let challenge = currentChallenge {
            let completedAt = Date()
            let session = WakeSession(
                alarmId: triggeredAlarm?.id ?? challenge.alarmId,
                alarmLabel: triggeredAlarm?.label ?? "起床",
                challengeType: challenge.type,
                mathDifficulty: challenge.difficulty,
                startedAt: challenge.startedAt,
                completedAt: completedAt,
                durationSeconds: max(1, Int(completedAt.timeIntervalSince(challenge.startedAt))),
                mood: nil,
                note: "",
                emergencyClosed: true
            )
            wakeSessions.insert(session, at: 0)
            saveWakeSessions()
        }
        if let alarm = triggeredAlarm {
            scheduleSnooze(for: alarm)
        }
        isShowingChallenge = false
        triggeredAlarm = nil
        currentChallenge = nil
    }
    
    func updateSessionFeedback(_ session: WakeSession, mood: WakeMood?, note: String) {
        guard let index = wakeSessions.firstIndex(where: { $0.id == session.id }) else { return }
        wakeSessions[index].mood = mood
        wakeSessions[index].note = note
        if lastCompletedSession?.id == session.id {
            lastCompletedSession = wakeSessions[index]
        }
        saveWakeSessions()
    }
    
    func dismissSuccess() {
        isShowingSuccess = false
        lastCompletedSession = nil
    }
    
    private func makeChallengeRecord(for alarm: Alarm) -> ChallengeRecord {
        switch alarm.challengeType {
        case .math:
            return ChallengeRecord(
                alarmId: alarm.id,
                type: alarm.challengeType,
                questions: makeMathQuestions(difficulty: alarm.mathDifficulty),
                phrase: nil,
                targetPhotoLabel: nil,
                memoryPattern: [],
                difficulty: alarm.mathDifficulty,
                startedAt: Date()
            )
        case .shake:
            return ChallengeRecord(alarmId: alarm.id, type: alarm.challengeType, questions: [], phrase: nil, targetPhotoLabel: nil, memoryPattern: [], difficulty: alarm.mathDifficulty, startedAt: Date())
        case .speak:
            return ChallengeRecord(alarmId: alarm.id, type: alarm.challengeType, questions: [], phrase: "我已经醒了，今天也要准时开始", targetPhotoLabel: nil, memoryPattern: [], difficulty: alarm.mathDifficulty, startedAt: Date())
        case .photo:
            return ChallengeRecord(alarmId: alarm.id, type: alarm.challengeType, questions: [], phrase: nil, targetPhotoLabel: "床头灯", memoryPattern: [], difficulty: alarm.mathDifficulty, startedAt: Date())
        case .memory:
            return ChallengeRecord(alarmId: alarm.id, type: alarm.challengeType, questions: [], phrase: nil, targetPhotoLabel: nil, memoryPattern: Array(0..<4).shuffled(), difficulty: alarm.mathDifficulty, startedAt: Date())
        }
    }
    
    private func makeDismissOnlyRecord(for alarm: Alarm) -> ChallengeRecord {
        ChallengeRecord(
            alarmId: alarm.id,
            type: .math,
            questions: [MathQuestion(prompt: "点击关闭闹钟", answer: 0)],
            phrase: nil,
            targetPhotoLabel: nil,
            memoryPattern: [],
            difficulty: alarm.mathDifficulty,
            startedAt: Date(),
            requiresChallenge: false
        )
    }
    
    private func scheduleSnooze(for alarm: Alarm) {
        let content = UNMutableNotificationContent()
        content.title = "稍后提醒"
        content.body = alarm.requiresChallenge ? "继续完成起床挑战" : "该起床了"
        content.sound = .default
        content.userInfo = ["alarmId": alarm.id.uuidString]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(1, alarm.snoozeMinutes) * 60), repeats: false)
        let request = UNNotificationRequest(identifier: snoozeIdentifier(for: alarm), content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    private func notificationIdentifier(for alarm: Alarm, weekday: Int) -> String {
        "\(alarm.id.uuidString)-weekday-\(weekday)"
    }
    
    private func snoozeIdentifier(for alarm: Alarm) -> String {
        "\(alarm.id.uuidString)-snooze"
    }
    
    private func makeMathQuestions(difficulty: MathDifficulty) -> [MathQuestion] {
        (0..<3).map { _ in
            switch difficulty {
            case .easy:
                let left = Int.random(in: 3...20)
                let right = Int.random(in: 2...18)
                return MathQuestion(prompt: "\(left) + \(right) = ?", answer: left + right)
            case .medium:
                let left = Int.random(in: 10...60)
                let right = Int.random(in: 8...50)
                return MathQuestion(prompt: "\(left) + \(right) = ?", answer: left + right)
            case .hard:
                let left = Int.random(in: 6...16)
                let right = Int.random(in: 4...12)
                let add = Int.random(in: 10...60)
                return MathQuestion(prompt: "\(left) × \(right) + \(add) = ?", answer: left * right + add)
            }
        }
    }
}
