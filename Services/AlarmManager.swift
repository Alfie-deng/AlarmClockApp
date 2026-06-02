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
    
    private let key = "savedAlarms"
    private let sessionsKey = "wakeSessions"
    
    init() { loadAlarms(); loadWakeSessions(); requestPermission() }
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
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
        let content = UNMutableNotificationContent()
        content.title = "起床挑战！"
        content.body = "完成\(alarm.challengeType.rawValue)才能关闭"
        content.sound = .default
        content.userInfo = ["alarmId": alarm.id.uuidString]
        let components = Calendar.current.dateComponents([.hour, .minute], from: alarm.time)
        let request = UNNotificationRequest(identifier: alarm.id.uuidString, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true))
        UNUserNotificationCenter.current().add(request)
    }
    
    func cancelNotification(for alarm: Alarm) { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [alarm.id.uuidString]) }
    
    func triggerChallenge(for alarm: Alarm) {
        triggeredAlarm = alarm
        currentChallenge = makeChallengeRecord(for: alarm)
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
