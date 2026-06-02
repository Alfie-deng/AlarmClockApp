import SwiftUI
import UserNotifications

struct HomeView: View {
    @EnvironmentObject var mgr: AlarmManager
    @State private var showAdd = false
    @State private var editAlarm: Alarm?
    @State private var sleepCopySeed = Int.random(in: 0...10_000)
    
    private var next: Alarm? {
        mgr.alarms
            .filter(\.isEnabled)
            .sorted { $0.nextOccurrence() < $1.nextOccurrence() }
            .first
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                BedroomBackdrop()
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        Color.clear
                            .frame(height: 286)
                        
                        glassCardStack
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
                
                HeaderBar()
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
            }
        }
        .sheet(isPresented: $showAdd) {
            AlarmSettingView()
                .presentationDetents([.large])
        }
        .sheet(item: $editAlarm) { alarm in
            AlarmSettingView(alarm: alarm)
                .presentationDetents([.large])
        }
        .onAppear {
            sleepCopySeed = Int.random(in: 0...10_000)
        }
    }
    
    @ViewBuilder
    private var glassCardStack: some View {
        cardStackContent
    }
    
    private var cardStackContent: some View {
        VStack(spacing: 18) {
            if mgr.notificationStatus.isBlockingAlarmDelivery {
                NotificationWarningCard()
            }
            
            AlarmHeroCard(
                alarm: next,
                onTap: {
                    if let next {
                        editAlarm = next
                    } else {
                        showAdd = true
                    }
                },
                onCancel: {
                    if let next {
                        mgr.toggleAlarm(next)
                    }
                }
            )

            WakeCountdownBatteryCard(alarm: next, copySeed: sleepCopySeed)
        }
    }
}

private struct BedroomBackdrop: View {
    var body: some View {
        ZStack(alignment: .top) {
            Image("BedsideLampBackground")
                .resizable()
                .scaledToFill()
                .overlay(
                    LinearGradient(
                        colors: [
                            Color(hex: "06101C").opacity(0.1),
                            Color(hex: "05070B").opacity(0.18),
                            Color(hex: "05070B").opacity(0.88)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    LinearGradient(
                        colors: [
                            .black.opacity(0.22),
                            .clear,
                            .black.opacity(0.32)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            GeometryReader { proxy in
                let width = proxy.size.width
                let top = proxy.safeAreaInsets.top
                
                ZStack(alignment: .top) {
                    // 资产图负责真实空间关系；这里仅补一层暖光，让卡片和灯连成同一个夜景。
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Bedside.accent.opacity(0.14),
                                    Bedside.amber.opacity(0.05),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 160
                            )
                        )
                        .frame(width: 300, height: 150)
                        .blur(radius: 30)
                        .offset(x: width * 0.22, y: top + 210)
                    
                    BedroomVignette()
                }
            }
            
            LinearGradient(
                colors: [
                    .black.opacity(0.0),
                    .black.opacity(0.02),
                    Bedside.bg.opacity(0.82),
                    Bedside.bg
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

private struct BedroomVignette: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    .black.opacity(0.15),
                    .clear,
                    .black.opacity(0.78)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            HStack {
                LinearGradient(
                    colors: [.black.opacity(0.62), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 130)
                Spacer()
                LinearGradient(
                    colors: [.clear, .black.opacity(0.38)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 100)
            }
        }
    }
}

private struct HeaderBar: View {
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("🌙 起床挑战")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(Bedside.text)
                Text("不完成挑战，别想关闹钟")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Bedside.subtext)
            }
            
            Spacer()
        }
    }
}

private struct AlarmHeroCard: View {
    let alarm: Alarm?
    let onTap: () -> Void
    let onCancel: () -> Void
    
    private var timeText: String { alarm?.formattedTime ?? "--:--" }
    private var periodText: String { alarm?.formattedPeriod ?? "" }
    private var labelText: String {
        guard let alarm else { return "还没有开启的闹钟" }
        return alarm.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "起床" : alarm.label
    }
    private var dateText: String { alarm?.nextOccurrenceText() ?? "" }
    private var statusText: String { alarm?.isEnabled == true ? "已开启" : "未开启" }
    private var challengeText: String { "\(alarm?.challengeType.rawValue ?? "数学题")挑战" }
    private var challengeIcon: String { alarm?.challengeType.icon ?? ChallengeType.math.icon }
    private var accessibilitySummary: String {
        [labelText, dateText, "\(timeText) \(periodText)", challengeText, statusText]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "，")
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            LiquidGlassPanel(radius: 22, style: .hero, interactive: alarm != nil)
                .allowsHitTesting(false)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text(alarm == nil ? "添加第一个闹钟" : "下一个闹钟")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Bedside.text.opacity(0.94))
                    
                    if alarm != nil {
                        Text(statusText)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Bedside.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Bedside.green.opacity(0.14))
                                    .overlay(Capsule().stroke(Bedside.green.opacity(0.18), lineWidth: 0.6))
                            )
                    }
                    
                }
                
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(timeText)
                        .font(.system(size: 116, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.62)
                        .glow(Bedside.amber)
                    
                    Text(periodText)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Bedside.amber.opacity(0.86))
                        .padding(.bottom, 20)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    if !dateText.isEmpty {
                        Text(dateText)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Bedside.subtext)
                    }
                    
                    HStack(alignment: .center, spacing: 8) {
                        heroPill(challengeText, icon: challengeIcon)
                        
                        Spacer()
                        
                        if alarm != nil {
                            Button(action: onCancel) {
                                heroPill("取消", icon: "bell.slash.fill")
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("取消闹钟")
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 258)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }
    
    private func heroPill(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Bedside.amber)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(Bedside.accent.opacity(0.14))
                    .overlay(Capsule().stroke(Bedside.accent.opacity(0.12), lineWidth: 0.6))
            )
    }

}

private struct WakeCountdownBatteryCard: View {
    let alarm: Alarm?
    let copySeed: Int

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let state = batteryState(at: context.date)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("睡眠余额", systemImage: "moon.zzz.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Bedside.subtext)
                    Spacer()
                    Text(state.remainingText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Bedside.amber)
                }

                GeometryReader { proxy in
                    let fillWidth = max(22, proxy.size.width * state.progress)

                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(Color.black.opacity(0.28))
                            .overlay(Capsule().stroke(Bedside.accent.opacity(0.24), lineWidth: 0.8))
                            .shadow(color: Bedside.accent.opacity(0.12), radius: 10, x: 0, y: 0)

                        Capsule(style: .continuous)
                            .fill(Bedside.accent.opacity(0.26))
                            .frame(width: fillWidth)
                            .blur(radius: 10)
                            .opacity(0.95)

                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Bedside.amber, Bedside.accent, Color(hex: "FF8D35")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: fillWidth)
                            .shadow(color: Bedside.accent.opacity(0.72), radius: 12, x: 0, y: 0)
                            .shadow(color: Bedside.amber.opacity(0.36), radius: 22, x: 0, y: 0)

                        Capsule(style: .continuous)
                            .fill(.white.opacity(0.22))
                            .frame(width: max(16, fillWidth * 0.72), height: 4)
                            .offset(x: 12, y: -14)
                            .blur(radius: 2)
                            .opacity(0.55)

                        Text(state.copy)
                            .font(.system(size: 14.5, weight: .bold))
                            .foregroundStyle(Bedside.text)
                            .shadow(color: .black.opacity(0.42), radius: 1.6, x: 0, y: 1)
                            .shadow(color: Bedside.accent.opacity(0.35), radius: 3.5, x: 0, y: 0)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .padding(.horizontal, 14)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .frame(height: 52)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 18)
            .background { LiquidGlassPanel(radius: 18, style: .card) }
            .accessibilityElement(children: .combine)
        }
    }

    private func batteryState(at date: Date) -> BatteryState {
        guard let alarm else {
            return BatteryState(
                progress: 0.12,
                remainingText: "未启用",
                copy: pick(["没有启用闹钟，明天靠命运叫醒你？", "今天暂时没有处刑安排", "闹钟空着，人生开始自由落体"])
            )
        }

        let target = alarm.nextOccurrence(after: date)
        let seconds = max(0, target.timeIntervalSince(date))
        let hours = seconds / 3600
        let progress = min(max(seconds / (8 * 3600), 0.08), 1)
        let remainingText = remainingText(seconds: seconds)

        switch hours {
        case 8...:
            return BatteryState(progress: progress, remainingText: remainingText, copy: pick([
                "时间还够，但别拿它当免死金牌",
                "睡眠余额充足，别开始作妖",
                "现在睡，明早像个人类"
            ]))
        case 6..<8:
            return BatteryState(progress: progress, remainingText: remainingText, copy: pick([
                "还来得及，别继续刷到灵魂出窍",
                "黄金睡眠窗口正在关闭",
                "现在上床，明天少恨自己一点"
            ]))
        case 4..<6:
            return BatteryState(progress: progress, remainingText: remainingText, copy: pick([
                "时间开始紧了，被窝在等你投降",
                "再熬就不是晚睡，是主动削弱明天",
                "睡吧，明早别和闹钟打官司"
            ]))
        case 2..<4:
            return BatteryState(progress: progress, remainingText: remainingText, copy: pick([
                "这点时间，睡了总比不睡强",
                "明早会醒，但精神可能是散装的",
                "赶紧睡，别把明天开局打成残血"
            ]))
        default:
            return BatteryState(progress: progress, remainingText: remainingText, copy: pick([
                "快到了，别指望睡眠医学救你",
                "闹钟快开庭了，请准备出庭",
                "现在闭眼，属于战术性昏迷"
            ]))
        }
    }

    private func pick(_ copies: [String]) -> String {
        guard !copies.isEmpty else { return "" }
        return copies[abs(copySeed) % copies.count]
    }

    private func remainingText(seconds: TimeInterval) -> String {
        let totalMinutes = max(0, Int(seconds / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 { return "还剩 \(hours)小时\(minutes)分" }
        return "还剩 \(minutes)分"
    }

    private struct BatteryState {
        let progress: Double
        let remainingText: String
        let copy: String
    }
}

private struct NotificationWarningCard: View {
    var body: some View {
        HStack(spacing: 14) {
            BedsideIconBadge(systemName: "bell.slash.fill", color: Bedside.red)
            VStack(alignment: .leading, spacing: 5) {
                Text("通知未开启")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Bedside.text)
                Text("闹钟需要系统通知权限，否则不会准时响起。")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Bedside.subtext)
            }
            Spacer()
        }
        .padding(16)
        .background { LiquidGlassPanel(radius: 18, style: .card) }
    }
}


private extension UNAuthorizationStatus {
    var isBlockingAlarmDelivery: Bool {
        switch self {
        case .denied, .ephemeral:
            return true
        default:
            return false
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AlarmManager())
}
