import SwiftUI

struct ContentView: View {
    @EnvironmentObject var mgr: AlarmManager
    @State private var tab = 0
    
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
    
    var body: some View {
        Group {
            if debugScreen == "ringing" {
                RingingIntroView(
                    timeText: "07:00",
                    challengeName: "数学题",
                    onStartChallenge: {},
                    onSnooze: {}
                )
            } else if debugScreen == "math" {
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
                    onSnooze: {}
                )
            } else if debugScreen == "success" {
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
                    onDone: {},
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
                    onSnooze: { mgr.snooze() }
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
            guard ProcessInfo.processInfo.arguments.contains("--debugTriggerStoredAlarm") else { return }
            await runDebugTriggerStoredAlarm()
        }
    }
    
    private func runDebugScheduleWeekdays() async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        
        var components = DateComponents()
        components.hour = 7
        components.minute = 30
        let time = Calendar.current.date(from: components) ?? Date()
        let alarm = Alarm(time: time, repeatDays: [2, 4, 6])
        mgr.addAlarm(alarm)
        
        try? await Task.sleep(for: .milliseconds(400))
        let pending = await mgr.pendingNotificationIdentifiers()
        let joined = pending.joined(separator: ",")
        print("DEBUG_PENDING_NOTIFICATION_IDS=\(joined)")
    }
    
    private func runDebugTriggerStoredAlarm() async {
        let alarm = Alarm(time: Date(), challengeType: .math, label: "通知回调验证")
        mgr.addAlarm(alarm)
        mgr.triggerChallenge(alarmId: alarm.id.uuidString)
        print("DEBUG_TRIGGERED_STORED_ALARM_ID=\(alarm.id.uuidString)")
    }
    
    private var appShell: some View {
        ZStack {
            Bedside.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                TabView(selection: $tab) {
                    HomeView().tag(0)
                    AlarmTabView().tag(1)
                    StatsView().tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                HStack(spacing: 0) {
                    tabBtn(index: 0, icon: "house.fill", label: "首页")
                    tabBtn(index: 1, icon: "alarm", label: "闹钟")
                    tabBtn(index: 2, icon: "chart.bar.fill", label: "统计")
                }
                .padding(.top, 9)
                .padding(.bottom, 34)
                .background {
                    Rectangle()
                        .fill(Bedside.bg.opacity(0.86))
                        .overlay(Rectangle().frame(height: 0.5).foregroundColor(Bedside.sep), alignment: .top)
                }
            }
        }
    }
    
    private func tabBtn(index: Int, icon: String, label: String) -> some View {
        Button {
            tab = index
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 20, weight: tab == index ? .semibold : .regular))
                Text(label).font(.system(size: 10, weight: tab == index ? .semibold : .regular))
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(tab == index ? Bedside.accent : Bedside.dim)
        }
        .buttonStyle(.plain)
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
    
    var body: some View {
        NavigationStack {
            ZStack {
                BedsideAmbientBackground()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        BedsideTopBar(title: "闹钟", subtitle: "管理你的起床挑战")
                            .padding(.horizontal, -20)
                            .padding(.top, 8)
                        
                        if mgr.alarms.isEmpty {
                            AlarmEmptyCard()
                        } else {
                            VStack(spacing: 12) {
                                ForEach(mgr.alarms) { alarm in
                                    AlarmListCard(
                                        alarm: alarm,
                                        onEdit: { editAlarm = alarm },
                                        onToggle: { mgr.toggleAlarm(alarm) }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
        }
        .sheet(item: $editAlarm) { alarm in
            AlarmSettingView(alarm: alarm)
                .presentationDetents([.large])
        }
    }
}

private struct AlarmEmptyCard: View {
    var body: some View {
        VStack(spacing: 16) {
            BedsideIconBadge(systemName: "alarm.fill")
                .scaleEffect(1.18)
            
            VStack(spacing: 6) {
                Text("暂无闹钟")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Bedside.text)
                Text("从首页添加第一个起床挑战")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Bedside.subtext)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 42)
        .background { LiquidGlassPanel(radius: 20, style: .hero) }
    }
}

private struct AlarmListCard: View {
    let alarm: Alarm
    let onEdit: () -> Void
    let onToggle: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                BedsideIconBadge(systemName: alarm.isEnabled ? "alarm.fill" : "alarm")
                    .opacity(alarm.isEnabled ? 1 : 0.5)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(alarm.formattedTime)
                            .font(.system(size: 34, weight: .light, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(alarm.isEnabled ? Bedside.amber : Bedside.dim)
                        Text(alarm.formattedPeriod)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(alarm.isEnabled ? Bedside.amber.opacity(0.74) : Bedside.dim)
                            .padding(.bottom, 5)
                    }
                    
                    Text(alarm.label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Bedside.subtext)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 9) {
                    BedsidePill(text: alarm.challengeType.rawValue, icon: alarm.challengeType.icon)
                        .opacity(alarm.isEnabled ? 1 : 0.55)
                    
                    Text(alarm.isEnabled ? "已开启" : "已关闭")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(alarm.isEnabled ? Bedside.green : Bedside.dim)
                }
            }
            
            HStack(spacing: 10) {
                Button(action: onEdit) {
                    listActionLabel("修改挑战", icon: "slider.horizontal.3")
                }
                .buttonStyle(.plain)
                
                Button(action: onToggle) {
                    listActionLabel(
                        alarm.isEnabled ? "取消闹钟" : "重新开启",
                        icon: alarm.isEnabled ? "xmark.circle.fill" : "checkmark.circle.fill",
                        color: alarm.isEnabled ? Bedside.red : Bedside.green
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background { LiquidGlassPanel(radius: 18, style: .card) }
        .opacity(alarm.isEnabled ? 1 : 0.68)
    }
    
    private func listActionLabel(_ title: String, icon: String, color: Color = Bedside.amber) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(color.opacity(0.11))
                    .overlay(Capsule().stroke(color.opacity(0.18), lineWidth: 0.6))
            )
    }
}

#Preview { ContentView().environmentObject(AlarmManager()) }
