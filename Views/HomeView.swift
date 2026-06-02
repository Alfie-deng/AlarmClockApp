import SwiftUI

struct HomeView: View {
    @EnvironmentObject var mgr: AlarmManager
    @State private var showAdd = false
    @State private var editAlarm: Alarm?
    
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
    }
    
    @ViewBuilder
    private var glassCardStack: some View {
        cardStackContent
    }
    
    private var cardStackContent: some View {
        VStack(spacing: 18) {
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
            
            BedtimeReminderCard()
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
                Text("挑战自己，开启美好一天")
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
                        .font(.system(size: 108, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.62)
                        .glow(Bedside.amber)
                    
                    Text(periodText)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Bedside.amber.opacity(0.86))
                        .padding(.bottom, 18)
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
                                heroPill("取消", icon: "moon.zzz.fill")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 232)
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

private struct BedtimeReminderCard: View {
    var body: some View {
        ZStack {
            LiquidGlassPanel(radius: 18, style: .card)
                .allowsHitTesting(false)
            
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Bedside.amber.opacity(0.14))
                        .frame(width: 44, height: 44)
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Bedside.amber)
                }
                
                VStack(alignment: .leading, spacing: 5) {
                    Text("就寝提醒")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Bedside.text)
                    Text("23:00 提醒就寝")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Bedside.text.opacity(0.82))
                    Text("帮助你获得充足睡眠")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Bedside.subtext)
                }
                
                Spacer()
                
                Toggle("", isOn: .constant(true))
                    .labelsHidden()
                    .tint(Bedside.accent)
                    .scaleEffect(0.92)
            }
            .padding(16)
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AlarmManager())
}
