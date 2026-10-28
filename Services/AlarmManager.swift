import AlarmKit
import AudioToolbox
import AVFoundation
import Foundation
import UserNotifications
import Combine

@MainActor
class AlarmManager: ObservableObject {
    static let shared = AlarmManager()

    @Published var alarms: [Alarm] = []
    @Published var currentChallenge: ChallengeRecord?
    @Published var isShowingChallenge: Bool = false
    @Published var triggeredAlarm: Alarm?
    @Published var wakeSessions: [WakeSession] = []
    @Published var lastCompletedSession: WakeSession?
    @Published var isShowingSuccess: Bool = false
    @Published var alarmAuthorization: AlarmKit.AlarmManager.AuthorizationState = .notDetermined
    @Published var scheduledAlarmCount: Int = 0
    @Published var nextScheduledAlarmDate: Date?

    private let key = "savedAlarms"
    private let sessionsKey = "wakeSessions"
    private let legacyNotificationsClearedKey = "legacyNotificationsCleared"
    private var followUpHeartbeat: Task<Void, Never>?
    /// 只在前台做挑战时推迟追响；切到后台就不再推，让追响按时响。
    var isAppActive = true

    var nextEnabledAlarm: Alarm? {
        alarms
            .filter(\.isEnabled)
            .min { $0.nextOccurrence() < $1.nextOccurrence() }
    }

    init() {
        loadAlarms()
        loadWakeSessions()
        clearLegacyNotificationsOnce()
        alarmAuthorization = SystemAlarmScheduler.authorizationState
        refreshAlarmDeliverySnapshot()
        Task { [weak self] in
            for await _ in AlarmKit.AlarmManager.shared.alarmUpdates {
                self?.refreshAlarmDeliverySnapshot()
            }
        }
        Task { [weak self] in
            for await state in AlarmKit.AlarmManager.shared.authorizationUpdates {
                self?.alarmAuthorization = state
            }
        }
    }

    /// 回到前台时调用：补排系统里丢失的闹钟、清掉不认识的残留。
    func syncSystemAlarms() async {
        alarmAuthorization = SystemAlarmScheduler.authorizationState
        guard alarmAuthorization.allowsAlarmDelivery else {
            refreshAlarmDeliverySnapshot()
            return
        }
        let scheduled = SystemAlarmScheduler.scheduledIDs()
        let enabled = alarms.filter(\.isEnabled)
        for alarm in enabled where !scheduled.contains(alarm.id) {
            try? await SystemAlarmScheduler.schedule(alarm)
        }
        let known = Set(enabled.map(\.id)).union(SystemAlarmScheduler.followUpIDs)
        for id in scheduled where !known.contains(id) {
            SystemAlarmScheduler.cancel(id)
        }
        refreshAlarmDeliverySnapshot()
    }

    func refreshAlarmDeliverySnapshot() {
        alarmAuthorization = SystemAlarmScheduler.authorizationState
        let scheduled = SystemAlarmScheduler.scheduledIDs()
        let active = alarms.filter { $0.isEnabled && scheduled.contains($0.id) }
        scheduledAlarmCount = active.count
        nextScheduledAlarmDate = active.map { $0.nextOccurrence() }.min()
    }

    func addAlarm(_ alarm: Alarm) {
        alarms.append(alarm)
        saveAlarms()
        scheduleSystemAlarm(for: alarm)
    }

    func updateAlarm(_ alarm: Alarm) {
        if let i = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[i] = alarm
            saveAlarms()
            SystemAlarmScheduler.cancel(alarm.id)
            scheduleSystemAlarm(for: alarm)
        }
    }

    func deleteAlarm(_ alarm: Alarm) {
        alarms.removeAll { $0.id == alarm.id }
        saveAlarms()
        SystemAlarmScheduler.cancel(alarm.id)
        SystemAlarmScheduler.cancelFollowUp(for: alarm.id)
        refreshAlarmDeliverySnapshot()
    }

    func toggleAlarm(_ alarm: Alarm) {
        if let i = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[i].isEnabled.toggle()
            saveAlarms()
            if alarms[i].isEnabled { scheduleSystemAlarm(for: alarms[i]) }
            else { SystemAlarmScheduler.cancel(alarm.id) }
            refreshAlarmDeliverySnapshot()
        }
    }

    private func saveAlarms() { if let d = try? JSONEncoder().encode(alarms) { UserDefaults.standard.set(d, forKey: key) } }
    private func loadAlarms() { if let d = UserDefaults.standard.data(forKey: key), let decoded = try? JSONDecoder().decode([Alarm].self, from: d) { alarms = decoded } }
    private func saveWakeSessions() { if let d = try? JSONEncoder().encode(wakeSessions) { UserDefaults.standard.set(d, forKey: sessionsKey) } }
    private func loadWakeSessions() { if let d = UserDefaults.standard.data(forKey: sessionsKey), let decoded = try? JSONDecoder().decode([WakeSession].self, from: d) { wakeSessions = decoded } }

    /// 旧版本用本地通知响铃，升级后清掉，避免和系统闹钟重复响。
    private func clearLegacyNotificationsOnce() {
        guard !UserDefaults.standard.bool(forKey: legacyNotificationsClearedKey) else { return }
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UserDefaults.standard.set(true, forKey: legacyNotificationsClearedKey)
    }

    private func scheduleSystemAlarm(for alarm: Alarm) {
        guard alarm.isEnabled else { return }
        Task {
            alarmAuthorization = await SystemAlarmScheduler.requestAuthorizationIfNeeded()
            guard alarmAuthorization.allowsAlarmDelivery else { return }
            try? await SystemAlarmScheduler.schedule(alarm)
            refreshAlarmDeliverySnapshot()
        }
    }

    // MARK: - 系统闹钟按钮回调

    /// 锁屏点了「去做挑战」：打开挑战页，同时排追响防止回去睡。
    func handleChallengeAlarmStopped(alarmID: String) async {
        guard let alarm = storedAlarm(id: alarmID) else { return }
        triggerChallenge(for: alarm)
        disableIfOneShot(alarm.id)
        // 已经在做别的闹钟的挑战：那边的追响会兜底，这里不再另排。
        guard triggeredAlarm?.id == alarm.id else {
            SystemAlarmScheduler.cancelFollowUp(for: alarm.id)
            return
        }
        await SystemAlarmScheduler.scheduleFollowUp(for: alarm, after: SystemAlarmScheduler.challengeFollowUpDelay)
    }

    func handlePlainAlarmStopped(alarmID: String) {
        guard let alarm = storedAlarm(id: alarmID) else { return }
        SystemAlarmScheduler.cancelFollowUp(for: alarm.id)
        disableIfOneShot(alarm.id)
    }

    func handleSnooze(alarmID: String) async {
        guard let alarm = storedAlarm(id: alarmID) else { return }
        disableIfOneShot(alarm.id)
        await SystemAlarmScheduler.scheduleFollowUp(for: alarm, after: TimeInterval(max(1, alarm.snoozeMinutes) * 60))
    }

    private func storedAlarm(id: String) -> Alarm? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return alarms.first { $0.id == uuid }
    }

    /// 单次闹钟响过就关掉开关，和系统时钟一致。
    private func disableIfOneShot(_ id: UUID) {
        guard let i = alarms.firstIndex(where: { $0.id == id }),
              alarms[i].repeatWeekdays.isEmpty,
              alarms[i].isEnabled else { return }
        alarms[i].isEnabled = false
        saveAlarms()
        SystemAlarmScheduler.cancel(id)
        refreshAlarmDeliverySnapshot()
    }

    /// 挑战页开着时不断把追响往后推；一离开 App，追响就会按时响。
    private func startFollowUpHeartbeat(for alarm: Alarm) {
        followUpHeartbeat?.cancel()
        guard alarms.contains(where: { $0.id == alarm.id }) else { return }
        followUpHeartbeat = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled, let self, self.isShowingChallenge else { return }
                guard self.isAppActive else { continue }
                await SystemAlarmScheduler.scheduleFollowUp(for: alarm, after: SystemAlarmScheduler.challengeFollowUpDelay)
            }
        }
    }

    private func finishChallengeAlarm(_ alarmID: UUID?) {
        followUpHeartbeat?.cancel()
        followUpHeartbeat = nil
        SystemAlarmScheduler.cancelAllFollowUps()
        guard let alarmID else { return }
        disableIfOneShot(alarmID)
    }

    // MARK: - 挑战流程

    @discardableResult
    func triggerChallenge(for alarm: Alarm) -> Bool {
        guard !isShowingChallenge, !isShowingSuccess else { return false }
        triggeredAlarm = alarm
        currentChallenge = alarm.requiresChallenge ? makeChallengeRecord(for: alarm) : makeDismissOnlyRecord(for: alarm)
        isShowingChallenge = true
        startFollowUpHeartbeat(for: alarm)
        return true
    }

    @discardableResult
    func triggerChallenge(alarmId: String?) -> Bool {
        guard let alarmId, let alarm = storedAlarm(id: alarmId), alarm.isEnabled else {
            return false
        }
        return triggerChallenge(for: alarm)
    }

    func completeChallenge() {
        guard let challenge = currentChallenge else {
            isShowingChallenge = false
            return
        }

        let session = recordSession(for: challenge, emergencyClosed: false)
        finishChallengeAlarm(triggeredAlarm?.id ?? challenge.alarmId)
        lastCompletedSession = session
        isShowingChallenge = false
        triggeredAlarm = nil
        currentChallenge = nil
        isShowingSuccess = true
    }

    /// 紧急关闭：真的关掉，不再追响，记一次失败。
    func emergencyClose() {
        if let challenge = currentChallenge {
            recordSession(for: challenge, emergencyClosed: true)
            finishChallengeAlarm(triggeredAlarm?.id ?? challenge.alarmId)
        } else {
            finishChallengeAlarm(triggeredAlarm?.id)
        }
        isShowingChallenge = false
        triggeredAlarm = nil
        currentChallenge = nil
    }

    @discardableResult
    private func recordSession(for challenge: ChallengeRecord, emergencyClosed: Bool) -> WakeSession {
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
            emergencyClosed: emergencyClosed
        )
        wakeSessions.insert(session, at: 0)
        saveWakeSessions()
        return session
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
    private var audioPlayer: AVAudioPlayer?

    func start(soundName: String) {
        stop()
        configurePlaybackSession()

        guard let url = Self.soundURL(named: soundName) else {
            AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.prepareToPlay()
            player.play()
            audioPlayer = player
        } catch {
            AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
        }
    }

    func preview(soundName: String) {
        start(soundName: soundName)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.stop()
        }
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func soundURL(named soundName: String) -> URL? {
        Bundle.main.url(forResource: AlarmSound.option(named: soundName).fileName, withExtension: nil)
    }

    private func configurePlaybackSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.duckOthers])
        try? session.setActive(true)
    }
}
