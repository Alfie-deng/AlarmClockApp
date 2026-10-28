import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var mgr: AlarmManager
    @State private var tab = 0
    @State private var dismissedDebugScreen = false

    init() {
        Self.configureSystemTabBar()
    }

    private static func configureSystemTabBar() {
        let accent = UIColor(red: 1.0, green: 144.0 / 255.0, blue: 34.0 / 255.0, alpha: 1.0)
        let unselected = UIColor.white.withAlphaComponent(0.82)

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
        .tint(Color(red: 1.0, green: 144.0 / 255.0, blue: 34.0 / 255.0))
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
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 0, trailing: 20))
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
                                .listRowInsets(EdgeInsets(top: 7, leading: 20, bottom: 7, trailing: 20))
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
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text("闹钟")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Bedside.text)
                Text("管理你的起床挑战")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Bedside.subtext)
            }

            Spacer()

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Bedside.amber)
                    .frame(width: 54, height: 54)
                    .background { LiquidGlassCapsule(style: .card, interactive: true) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("新增闹钟")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
    }
}

private struct AlarmEmptyCard: View {
    var body: some View {
        VStack(spacing: 14) {
            BedsideIconBadge(systemName: "alarm.fill")
                .scaleEffect(1.12)

            VStack(spacing: 6) {
                Text("还没有已保存的闹钟")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Bedside.text)
                Text("保存后的闹钟会在这里管理")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Bedside.subtext)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background { LiquidGlassPanel(radius: 20, style: .hero) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("还没有已保存的闹钟，保存后的闹钟会在这里管理")
    }
}

private struct AddAlarmButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Bedside.accent.opacity(0.34), Bedside.amber.opacity(0.16)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(Circle().stroke(Bedside.accent.opacity(0.28), lineWidth: 1))
                    .shadow(color: Bedside.accent.opacity(0.24), radius: 13, x: 0, y: 6)
                    .shadow(color: .black.opacity(0.38), radius: 10, x: 0, y: 8)

                Image(systemName: "plus")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(Bedside.amber)
                    .shadow(color: .black.opacity(0.72), radius: 2.5, x: 0, y: 2)
                    .shadow(color: Bedside.accent.opacity(0.72), radius: 7, x: 0, y: 0)
            }
            .frame(width: 58, height: 58)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("新增闹钟")
    }
}

private struct AlarmListCard: View {
    let alarm: Alarm
    let onEdit: () -> Void
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        timeText
                        periodText
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 5) {
                    Text(alarm.label)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(alarm.isEnabled ? Bedside.text.opacity(0.92) : Bedside.dim)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(alarm.nextOccurrenceText())
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(alarm.isEnabled ? Bedside.subtext : Bedside.dim)
                        .lineLimit(1)
                }
                .padding(.top, 8)
            }

            HStack(alignment: .center, spacing: 8) {
                ChallengeStatusLine(title: alarm.challengeType.rawValue, icon: alarm.challengeType.icon)
                    .opacity(alarm.isEnabled ? 1 : 0.55)

                Spacer(minLength: 8)

                AlarmEditPill()

                AlarmPowerPill(isEnabled: alarm.isEnabled, action: onToggle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background { LiquidGlassPanel(radius: 19, style: .card) }
        .contentShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
        .onTapGesture(perform: onEdit)
        .opacity(alarm.isEnabled ? 1 : 0.68)
        .accessibilityAction(named: "编辑闹钟", onEdit)
    }

    private var timeText: some View {
        Text(alarm.formattedTime)
            .font(.system(size: 52, weight: .light, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(alarm.isEnabled ? Bedside.text : Bedside.dim)
    }

    private var periodText: some View {
        Text(alarm.formattedPeriod)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(alarm.isEnabled ? Bedside.subtext : Bedside.dim)
            .padding(.bottom, 10)
    }
}

private struct AlarmPowerPill: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: isEnabled ? "power.circle.fill" : "power.circle")
                    .font(.system(size: 13, weight: .bold))
                Text(isEnabled ? "开启" : "关闭")
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
            }
            .foregroundStyle(isEnabled ? Bedside.amber : Bedside.dim)
            .frame(width: 78, height: 30)
            .background {
                Capsule(style: .continuous)
                    .fill((isEnabled ? Bedside.accent : Bedside.dim).opacity(isEnabled ? 0.14 : 0.10))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke((isEnabled ? Bedside.amber : Bedside.dim).opacity(isEnabled ? 0.22 : 0.18), lineWidth: 0.7)
                    )
            }
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isEnabled ? "关闭闹钟" : "开启闹钟")
    }
}

private struct ChallengeStatusLine: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 15, alignment: .center)
            Text("挑战 · \(title)")
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.86)
        }
        .foregroundStyle(Bedside.amber.opacity(0.92))
        .frame(height: 30)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("当前挑战：\(title)")
        .accessibilityAddTraits(.isStaticText)
    }
}

private struct AlarmEditPill: View {
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 12, weight: .bold))
            Text("详情")
                .font(.system(size: 12, weight: .bold))
        }
        .foregroundStyle(Bedside.amber)
        .frame(minWidth: 66)
        .frame(height: 30)
        .padding(.horizontal, 8)
        .background { LiquidGlassCapsule(style: .card, interactive: true) }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview { ContentView().environmentObject(AlarmManager()) }
