import AudioToolbox
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
    @Published var pendingNotificationCount: Int = 0
    @Published var nextPendingNotificationDate: Date?

    private let key = "savedAlarms"
    private let sessionsKey = "wakeSessions"

    var nextEnabledAlarm: Alarm? {
        alarms
            .filter(\.isEnabled)
            .min { $0.nextOccurrence() < $1.nextOccurrence() }
    }

    init() {
        loadAlarms()
        loadWakeSessions()
        refreshNotificationStatus()
        refreshAlarmDeliverySnapshot()
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] _, _ in
            Task { @MainActor in
                self?.refreshNotificationStatus()
            }
        }
    }

    private func requestPermissionIfNeeded(then action: @escaping () -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                Task { @MainActor in
                    self?.notificationStatus = settings.authorizationStatus
                    action()
                }
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
                    Task { @MainActor in
                        self?.refreshNotificationStatus()
                        if granted { action() }
                    }
                }
            case .denied:
                Task { @MainActor in
                    self?.notificationStatus = .denied
                }
            @unknown default:
                Task { @MainActor in
                    self?.refreshNotificationStatus()
                }
            }
        }
    }

    func refreshNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                self?.notificationStatus = settings.authorizationStatus
                self?.refreshAlarmDeliverySnapshot()
            }
        }
    }

    func refreshAlarmDeliverySnapshot() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { [weak self] requests in
            let nextDate = requests
                .compactMap { Self.nextTriggerDate(from: $0.trigger) }
                .min()
            Task { @MainActor in
                self?.pendingNotificationCount = requests.count
                self?.nextPendingNotificationDate = nextDate
            }
        }
    }

    func addAlarm(_ alarm: Alarm) {
        alarms.append(alarm)
        saveAlarms()
        scheduleNotificationAfterPermissionIfNeeded(for: alarm)
        refreshAlarmDeliverySnapshotSoon()
    }

    func updateAlarm(_ alarm: Alarm) {
        if let i = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[i] = alarm
            saveAlarms()
            cancelNotification(for: alarm)
            scheduleNotificationAfterPermissionIfNeeded(for: alarm)
            refreshAlarmDeliverySnapshotSoon()
        }
    }

    func deleteAlarm(_ alarm: Alarm) {
        alarms.removeAll { $0.id == alarm.id }
        saveAlarms()
        cancelNotification(for: alarm)
        refreshAlarmDeliverySnapshotSoon()
    }

    func toggleAlarm(_ alarm: Alarm) {
        if let i = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[i].isEnabled.toggle()
            saveAlarms()
            if alarms[i].isEnabled { scheduleNotificationAfterPermissionIfNeeded(for: alarms[i]) }
            else { cancelNotification(for: alarms[i]) }
            refreshAlarmDeliverySnapshotSoon()
        }
    }

    private func saveAlarms() { if let d = try? JSONEncoder().encode(alarms) { UserDefaults.standard.set(d, forKey: key) } }
    private func loadAlarms() { if let d = UserDefaults.standard.data(forKey: key), let decoded = try? JSONDecoder().decode([Alarm].self, from: d) { alarms = decoded } }
    private func saveWakeSessions() { if let d = try? JSONEncoder().encode(wakeSessions) { UserDefaults.standard.set(d, forKey: sessionsKey) } }
    private func loadWakeSessions() { if let d = UserDefaults.standard.data(forKey: sessionsKey), let decoded = try? JSONDecoder().decode([WakeSession].self, from: d) { wakeSessions = decoded } }

    private func scheduleNotificationAfterPermissionIfNeeded(for alarm: Alarm) {
        guard alarm.isEnabled else { return }
        requestPermissionIfNeeded { [weak self] in
            self?.scheduleNotification(for: alarm)
        }
    }

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
            UNUserNotificationCenter.current().add(request) { [weak self] _ in
                Task { @MainActor in self?.refreshAlarmDeliverySnapshot() }
            }
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
            UNUserNotificationCenter.current().add(request) { [weak self] _ in
                Task { @MainActor in self?.refreshAlarmDeliverySnapshot() }
            }
        }
    }

    func cancelNotification(for alarm: Alarm) {
        let identifiers = [alarm.id.uuidString] + (1...7).map { notificationIdentifier(for: alarm, weekday: $0) } + [snoozeIdentifier(for: alarm)]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        refreshAlarmDeliverySnapshotSoon()
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
            if let fallback = nextEnabledAlarm {
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
                questions: makeMathQuestions(difficulty: alarm.mathDifficulty, count: alarm.mathQuestionCount),
                phrase: nil,
                targetPhotoLabel: nil,
                memoryPattern: [],
                difficulty: alarm.mathDifficulty,
                soundName: alarm.soundName,
                shakeRequiredCount: alarm.shakeRequiredCount,
                speechRepeatCount: alarm.speechRepeatCount,
                startedAt: Date()
            )
        case .shake:
            return ChallengeRecord(alarmId: alarm.id, type: alarm.challengeType, questions: [], phrase: nil, targetPhotoLabel: nil, memoryPattern: [], difficulty: alarm.mathDifficulty, soundName: alarm.soundName, shakeRequiredCount: alarm.shakeRequiredCount, speechRepeatCount: alarm.speechRepeatCount, startedAt: Date())
        case .speak:
            return ChallengeRecord(alarmId: alarm.id, type: alarm.challengeType, questions: [], phrase: alarm.speechPhrase, targetPhotoLabel: nil, memoryPattern: [], difficulty: alarm.mathDifficulty, soundName: alarm.soundName, shakeRequiredCount: alarm.shakeRequiredCount, speechRepeatCount: alarm.speechRepeatCount, startedAt: Date())
        case .photo:
            return ChallengeRecord(alarmId: alarm.id, type: alarm.challengeType, questions: [], phrase: nil, targetPhotoLabel: alarm.photoTargetLabel, memoryPattern: [], difficulty: alarm.mathDifficulty, soundName: alarm.soundName, shakeRequiredCount: alarm.shakeRequiredCount, speechRepeatCount: alarm.speechRepeatCount, startedAt: Date())
        case .memory:
            return ChallengeRecord(alarmId: alarm.id, type: alarm.challengeType, questions: [], phrase: nil, targetPhotoLabel: nil, memoryPattern: Array(0..<4).shuffled(), difficulty: alarm.mathDifficulty, soundName: alarm.soundName, shakeRequiredCount: alarm.shakeRequiredCount, speechRepeatCount: alarm.speechRepeatCount, startedAt: Date())
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
            soundName: alarm.soundName,
            shakeRequiredCount: alarm.shakeRequiredCount,
            speechRepeatCount: alarm.speechRepeatCount,
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
        UNUserNotificationCenter.current().add(request) { [weak self] _ in
            Task { @MainActor in self?.refreshAlarmDeliverySnapshot() }
        }
    }

    private func refreshAlarmDeliverySnapshotSoon() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            refreshAlarmDeliverySnapshot()
        }
    }

    nonisolated private static func nextTriggerDate(from trigger: UNNotificationTrigger?) -> Date? {
        if let trigger = trigger as? UNCalendarNotificationTrigger {
            return trigger.nextTriggerDate()
        }
        if let trigger = trigger as? UNTimeIntervalNotificationTrigger {
            return trigger.nextTriggerDate()
        }
        return nil
    }

    private func notificationIdentifier(for alarm: Alarm, weekday: Int) -> String {
        "\(alarm.id.uuidString)-weekday-\(weekday)"
    }

    private func snoozeIdentifier(for alarm: Alarm) -> String {
        "\(alarm.id.uuidString)-snooze"
    }

    private func makeMathQuestions(difficulty: MathDifficulty, count: Int) -> [MathQuestion] {
        (0..<Alarm.clampedMathQuestionCount(count)).map { _ in
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


final class AlarmSoundPlayer {
    private var timer: Timer?
    private var currentSoundId: SystemSoundID = AlarmSound.options[0].systemSoundId

    func start(soundName: String) {
        stop()
        currentSoundId = AlarmSound.option(named: soundName).systemSoundId
        playOnce()
        timer = Timer.scheduledTimer(withTimeInterval: 1.8, repeats: true) { [weak self] _ in
            self?.playOnce()
        }
    }

    func preview(soundName: String) {
        AudioServicesPlaySystemSound(AlarmSound.option(named: soundName).systemSoundId)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func playOnce() {
        AudioServicesPlaySystemSound(currentSoundId)
    }
}
