import AlarmKit
import AppIntents
import Foundation
import SwiftUI

struct WakeAlarmMetadata: AlarmMetadata {
    var sourceAlarmID: UUID
}

/// 把 App 内的闹钟同步到系统 AlarmKit：静音/专注模式下也会响，锁屏全屏显示。
/// 「追响」= 挑战没完成时额外排的一次性系统闹钟，挑战完成或紧急关闭才取消。
@MainActor
enum SystemAlarmScheduler {
    typealias Kit = AlarmKit.AlarmManager

    /// 按下「去做挑战」后，多久没完成就再响一次。
    static let challengeFollowUpDelay: TimeInterval = 90

    private static let followUpKey = "systemAlarmFollowUps"

    static var authorizationState: Kit.AuthorizationState {
        Kit.shared.authorizationState
    }

    static func requestAuthorizationIfNeeded() async -> Kit.AuthorizationState {
        guard Kit.shared.authorizationState == .notDetermined else {
            return Kit.shared.authorizationState
        }
        return (try? await Kit.shared.requestAuthorization()) ?? .denied
    }

    static func scheduledIDs() -> Set<UUID> {
        Set(((try? Kit.shared.alarms) ?? []).map(\.id))
    }

    static var followUpIDs: Set<UUID> {
        Set(followUps.values)
    }

    /// 新建闹钟和回前台补排可能同时排同一个闹钟，系统会拒掉重复 ID。
    private static var schedulingIDs: Set<UUID> = []

    static func schedule(_ alarm: Alarm) async throws {
        guard schedulingIDs.insert(alarm.id).inserted else { return }
        defer { schedulingIDs.remove(alarm.id) }
        cancel(alarm.id)
        let parts = Calendar.current.dateComponents([.hour, .minute], from: alarm.time)
        let weekdays = alarm.repeatWeekdays.sorted().compactMap(localeWeekday)
        let relative = AlarmKit.Alarm.Schedule.Relative(
            time: .init(hour: parts.hour ?? 7, minute: parts.minute ?? 0),
            repeats: weekdays.isEmpty ? .never : .weekly(weekdays)
        )
        _ = try await Kit.shared.schedule(id: alarm.id, configuration: configuration(for: alarm, schedule: .relative(relative)))
    }

    static func cancel(_ id: UUID) {
        try? Kit.shared.cancel(id: id)
    }

    /// 排一次追响（稍后提醒、挑战未完成都用它）；同一个闹钟只保留最新一条。
    static func scheduleFollowUp(for alarm: Alarm, after delay: TimeInterval) async {
        cancelFollowUp(for: alarm.id)
        let id = UUID()
        var map = followUps
        map[alarm.id] = id
        followUps = map

        let fireDate = Date().addingTimeInterval(delay)
        _ = try? await Kit.shared.schedule(id: id, configuration: configuration(for: alarm, schedule: .fixed(fireDate)))

        // 排期期间如果又被替换或取消，撤掉这条，避免留下孤儿闹钟。
        if followUps[alarm.id] != id {
            cancel(id)
        }
    }

    static func cancelFollowUp(for alarmID: UUID) {
        var map = followUps
        if let id = map.removeValue(forKey: alarmID) {
            cancel(id)
        }
        followUps = map
    }

    /// 挑战结束时清掉所有追响，包括别的闹钟留下的。
    static func cancelAllFollowUps() {
        followUps.values.forEach(cancel)
        followUps = [:]
    }

    private static var followUps: [UUID: UUID] {
        get {
            let raw = UserDefaults.standard.dictionary(forKey: followUpKey) as? [String: String] ?? [:]
            return Dictionary(uniqueKeysWithValues: raw.compactMap { key, value in
                guard let source = UUID(uuidString: key), let id = UUID(uuidString: value) else { return nil }
                return (source, id)
            })
        }
        set {
            let raw = Dictionary(uniqueKeysWithValues: newValue.map { ($0.key.uuidString, $0.value.uuidString) })
            UserDefaults.standard.set(raw, forKey: followUpKey)
        }
    }

    private static func configuration(for alarm: Alarm, schedule: AlarmKit.Alarm.Schedule) -> Kit.AlarmConfiguration<WakeAlarmMetadata> {
        let source = alarm.id.uuidString
        let title = alarm.requiresChallenge ? "\(alarm.label) · \(alarm.challengeType.rawValue)" : alarm.label
        let stopButton = AlarmButton(
            text: alarm.requiresChallenge ? "去做挑战" : "关闭",
            textColor: .white,
            systemImageName: alarm.requiresChallenge ? "shield.checkered" : "stop.fill"
        )
        let snoozeButton = AlarmButton(text: "稍后提醒", textColor: .white, systemImageName: "moon.zzz.fill")
        let presentation = AlarmPresentation(
            alert: .init(
                title: LocalizedStringResource(stringLiteral: title),
                stopButton: stopButton,
                secondaryButton: snoozeButton,
                secondaryButtonBehavior: .custom
            )
        )
        let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: WakeAlarmMetadata(sourceAlarmID: alarm.id),
            tintColor: Color(red: 1.0, green: 144.0 / 255.0, blue: 34.0 / 255.0)
        )
        let stopIntent: any LiveActivityIntent = alarm.requiresChallenge
            ? StartWakeChallengeIntent(alarmID: source)
            : StopWakeAlarmIntent(alarmID: source)
        return .alarm(
            schedule: schedule,
            attributes: attributes,
            stopIntent: stopIntent,
            secondaryIntent: SnoozeWakeAlarmIntent(alarmID: source),
            sound: .named(AlarmSound.option(named: alarm.soundName).fileName)
        )
    }

    private static func localeWeekday(_ weekday: Int) -> Locale.Weekday? {
        switch weekday {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return nil
        }
    }
}

extension AlarmKit.AlarmManager.AuthorizationState {
    var isBlockingAlarmDelivery: Bool { self == .denied }
    var allowsAlarmDelivery: Bool { self == .authorized }
}

// MARK: - 系统闹钟按钮触发的 Intent（在 App 进程里执行）

struct StartWakeChallengeIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "开始起床挑战"
    static let openAppWhenRun = true
    static let isDiscoverable = false

    @Parameter(title: "闹钟")
    var alarmID: String

    init() {}

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        await AlarmManager.shared.handleChallengeAlarmStopped(alarmID: alarmID)
        return .result()
    }
}

struct StopWakeAlarmIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "关闭闹钟"
    static let isDiscoverable = false

    @Parameter(title: "闹钟")
    var alarmID: String

    init() {}

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        AlarmManager.shared.handlePlainAlarmStopped(alarmID: alarmID)
        return .result()
    }
}

struct SnoozeWakeAlarmIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "稍后提醒"
    static let isDiscoverable = false

    @Parameter(title: "闹钟")
    var alarmID: String

    init() {}

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        await AlarmManager.shared.handleSnooze(alarmID: alarmID)
        return .result()
    }
}
