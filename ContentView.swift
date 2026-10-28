import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var mgr: AlarmManager
    @State private var tab = Self.debugInitialTab
    @State private var dismissedDebugScreen = false

    private static var debugInitialTab: Int {
        guard let index = ProcessInfo.processInfo.arguments.firstIndex(of: "--debugTab"),
              ProcessInfo.processInfo.arguments.indices.contains(index + 1),
              let value = Int(ProcessInfo.processInfo.arguments[index + 1]) else {
            return 0
        }
        return value
    }

    init() {
        Self.configureSystemTabBar()
    }

    private static func configureSystemTabBar() {
        let accent = UIColor(red: 232.0 / 255.0, green: 162.0 / 255.0, blue: 90.0 / 255.0, alpha: 1.0)
        let unselected = UIColor(red: 166.0 / 255.0, green: 155.0 / 255.0, blue: 142.0 / 255.0, alpha: 1.0)

        let tabBar = UITabBar.appearance()
        tabBar.itemPositioning = .centered
        tabBar.itemWidth = 80
        tabBar.itemSpacing = 30
        tabBar.tintColor = accent
        tabBar.unselectedItemTintColor = unselected

        let item = UITabBarItem.appearance()
        item.setTitleTextAttributes([
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: unselected
        ], for: .normal)
        item.setTitleTextAttributes([
            .font: UIFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: accent
        ], for: .selected)

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = unselected
        itemAppearance.normal.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: unselected
        ]
        itemAppearance.selected.iconColor = accent
        itemAppearance.selected.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: accent
        ]

        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
    }

    private var debugScreen: String? {
        guard let index = ProcessInfo.processInfo.arguments.firstIndex(of: "--debugScreen"),
              ProcessInfo.processInfo.arguments.indices.contains(index + 1) else {
            return nil
        }
        return ProcessInfo.processInfo.arguments[index + 1]
    }

    private var debugChallengeType: ChallengeType {
        guard let index = ProcessInfo.processInfo.arguments.firstIndex(of: "--showChallengeType"),
              ProcessInfo.processInfo.arguments.indices.contains(index + 1),
              let type = ChallengeType.debugValue(ProcessInfo.processInfo.arguments[index + 1]) else {
            return .math
        }
        return type
    }

    private var activeDebugScreen: String? {
        dismissedDebugScreen ? nil : debugScreen
    }

    var body: some View {
        Group {
            if activeDebugScreen == "ringing" {
                RingingIntroView(
                    timeText: "07:00",
                    challengeName: "数学题",
                    onStartChallenge: {},
                    onSnooze: {}
                )
            } else if activeDebugScreen == "math" {
                RingingView(
                    record: ChallengeRecord(
                        alarmId: nil,
                        type: .math,
                        questions: [
                            MathQuestion(prompt: "8 + 15 = ?", answer: 23),
                            MathQuestion(prompt: "12 + 19 = ?", answer: 31),
                            MathQuestion(prompt: "7 × 8 + 9 = ?", answer: 65)
                        ],
                        phrase: nil,
                        targetPhotoLabel: nil,
                        memoryPattern: [],
                        difficulty: .medium,
                        startedAt: Date()
                    ),
                    onCorrect: {},
                    onEmergencyClose: {}
                )
            } else if activeDebugScreen == "settings" {
                AlarmSettingView()
            } else if activeDebugScreen == "success" {
                SuccessView(
                    session: WakeSession(
                        alarmId: nil,
                        alarmLabel: "起床闹钟",
                        challengeType: .math,
                        mathDifficulty: .medium,
                        startedAt: Date().addingTimeInterval(-138),
                        completedAt: Date(),
                        durationSeconds: 138,
                        mood: nil,
                        note: "",
                        emergencyClosed: false
                    ),
                    sessions: [],
                    onDone: { dismissedDebugScreen = true },
                    onFeedback: { _, _ in }
                )
            } else {
                appShell
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $mgr.isShowingChallenge) {
            if let challenge = mgr.currentChallenge {
                RingingView(
                    record: challenge,
                    onCorrect: { mgr.completeChallenge() },
                    onEmergencyClose: { mgr.emergencyClose() }
                )
            }
        }
        .fullScreenCover(isPresented: $mgr.isShowingSuccess) {
            if let session = mgr.lastCompletedSession {
                SuccessView(
                    session: session,
                    sessions: mgr.wakeSessions,
                    onDone: { mgr.dismissSuccess() },
                    onFeedback: { mood, note in
                        mgr.updateSessionFeedback(session, mood: mood, note: note)
                    }
                )
            }
        }
        .task {
            guard ProcessInfo.processInfo.arguments.contains("--showChallenge"), !mgr.isShowingChallenge else { return }
            let alarm = Alarm(time: Date(), challengeType: debugChallengeType, label: "起床挑战")
            mgr.triggerChallenge(for: alarm)
        }
        .task {
            guard ProcessInfo.processInfo.arguments.contains("--showNoChallenge"), !mgr.isShowingChallenge else { return }
            let alarm = Alarm(time: Date(), requiresChallenge: false, label: "普通闹钟")
            mgr.triggerChallenge(for: alarm)
        }
        .task {
            guard ProcessInfo.processInfo.arguments.contains("--debugScheduleWeekdays") else { return }
            await runDebugScheduleWeekdays()
        }
        .task {
            guard ProcessInfo.processInfo.arguments.contains("--debugFireSoon") else { return }
            await runDebugFireSoon()
        }
        .task {
            guard ProcessInfo.processInfo.arguments.contains("--debugTriggerStoredAlarm") else { return }
            await runDebugTriggerStoredAlarm()
        }
    }

    private func runDebugScheduleWeekdays() async {
        var components = DateComponents()
        components.hour = 7
        components.minute = 30
        let time = Calendar.current.date(from: components) ?? Date()
        let alarm = Alarm(time: time, repeatDays: [2, 4, 6])
        mgr.addAlarm(alarm)

        try? await Task.sleep(for: .milliseconds(800))
        let scheduled = SystemAlarmScheduler.scheduledIDs().map(\.uuidString).sorted()
        print("DEBUG_SYSTEM_ALARM_IDS=\(scheduled.joined(separator: ",")) TARGET=\(alarm.id.uuidString) AUTH=\(mgr.alarmAuthorization)")
    }

    /// 15 秒后用真实系统闹钟响一次，用来验证锁屏响铃 → 去做挑战整条链路。
    private func runDebugFireSoon() async {
        let alarm = Alarm(time: Date(), challengeType: .math, label: "响铃验证", repeatDays: [])
        mgr.addAlarm(alarm)
        try? await Task.sleep(for: .seconds(2))
        await SystemAlarmScheduler.scheduleFollowUp(for: alarm, after: 15)
        print("DEBUG_FIRE_SOON_ID=\(alarm.id.uuidString) AUTH=\(mgr.alarmAuthorization)")
    }

    private func runDebugTriggerStoredAlarm() async {
        let alarm = Alarm(time: Date(), challengeType: .math, label: "通知回调验证")
        mgr.addAlarm(alarm)
        mgr.triggerChallenge(alarmId: alarm.id.uuidString)
        print("DEBUG_TRIGGERED_STORED_ALARM_ID=\(alarm.id.uuidString)")
    }

    private var appShell: some View {
        TabView(selection: $tab) {
            HomeView()
                .tag(0)
                .tabItem {
                    Label("首页", systemImage: "bed.double.fill")
                }

            AlarmTabView()
                .tag(1)
                .tabItem {
                    Label("闹钟", systemImage: "alarm.fill")
                }

            StatsView(sessions: mgr.wakeSessions)
                .tag(2)
                .tabItem {
                    Label("统计", systemImage: "chart.line.uptrend.xyaxis")
                }
        }
        .tint(Bedside.accent)
    }

}

private extension ChallengeType {
    static func debugValue(_ rawValue: String) -> ChallengeType? {
        switch rawValue.lowercased() {
        case "math": return .math
        case "shake": return .shake
        case "speak": return .speak
        case "photo": return .photo
        case "memory": return .memory
        default: return nil
        }
    }
}

private struct AlarmTabView: View {
    @EnvironmentObject var mgr: AlarmManager
    @State private var editAlarm: Alarm?
    @State private var showAddAlarm = false

    var body: some View {
        NavigationStack {
            ZStack {
                BedsideAmbientBackground()

                List {
                    Section {
                        AlarmListHeader(onAdd: { showAddAlarm = true })
                            .padding(.top, 8)
                            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }

                    Section {
                        AlarmReliabilityCard(
                            alarm: mgr.nextEnabledAlarm,
                            authorization: mgr.alarmAuthorization,
                            scheduledAlarmCount: mgr.scheduledAlarmCount,
                            nextScheduledAlarmDate: mgr.nextScheduledAlarmDate,
                            onRefresh: { mgr.refreshAlarmDeliverySnapshot() }
                        )
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 6, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }

                    if mgr.alarms.isEmpty {
                        Section {
                            AlarmEmptyCard()
                                .listRowInsets(EdgeInsets(top: 18, leading: 20, bottom: 0, trailing: 20))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    } else {
                        Section {
                            ForEach(mgr.alarms) { alarm in
                                AlarmListCard(
                                    alarm: alarm,
                                    onEdit: { editAlarm = alarm },
                                    onToggle: { mgr.toggleAlarm(alarm) }
                                )
                                .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        mgr.deleteAlarm(alarm)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .sheet(item: $editAlarm) { alarm in
            AlarmSettingView(alarm: alarm)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showAddAlarm) {
            AlarmSettingView()
                .presentationDetents([.large])
        }
        .onAppear {
            mgr.refreshAlarmDeliverySnapshot()
        }
    }
}

private struct AlarmListHeader: View {
    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("闹钟")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Bedside.text)
                Text("管理你的起床挑战")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Bedside.subtext)
            }

            Spacer()

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(Bedside.text)
                    .frame(width: 46, height: 46)
                    .background { LiquidGlassCapsule(style: .card, interactive: true) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("新增闹钟")
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 12)
    }
}

private struct AlarmEmptyCard: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "alarm")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Bedside.subtext)

            VStack(spacing: 6) {
                Text("还没有已保存的闹钟")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Bedside.text)
                Text("点右上角 + 添加一个")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Bedside.subtext)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background { LiquidGlassPanel(radius: 22, style: .card) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("还没有已保存的闹钟，点右上角加号添加一个")
    }
}

private struct AlarmListCard: View {
    let alarm: Alarm
    let onEdit: () -> Void
    let onToggle: () -> Void

    private var primary: Color { alarm.isEnabled ? Bedside.text : Bedside.dim }
    private var secondary: Color { alarm.isEnabled ? Bedside.subtext : Bedside.dim }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(alarm.formattedTime)
                        .font(.clock(50))
                        .monospacedDigit()
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(primary)
                    Text(alarm.formattedPeriod)
                        .font(.clock(17, weight: .regular))
                        .foregroundStyle(secondary)
                }

                Text("\(alarm.label) · \(alarm.nextOccurrenceText())")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                HStack(spacing: 5) {
                    Image(systemName: alarm.challengeType.icon)
                    Text(alarm.requiresChallenge ? alarm.challengeType.rawValue : "无挑战")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(alarm.isEnabled ? Bedside.accent.opacity(0.9) : Bedside.dim)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: Binding(get: { alarm.isEnabled }, set: { _ in onToggle() }))
                .labelsHidden()
                .tint(Bedside.accent)
                .accessibilityLabel(alarm.isEnabled ? "关闭闹钟" : "开启闹钟")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background { LiquidGlassPanel(radius: 22, style: .card) }
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture(perform: onEdit)
        .accessibilityAction(named: "编辑闹钟", onEdit)
    }
}

#Preview { ContentView().environmentObject(AlarmManager()) }
