import SwiftUI

private enum SuccessDateFormatters {
    static let completedTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}


struct SuccessView: View {
    let session: WakeSession
    let sessions: [WakeSession]
    let onDone: () -> Void
    let onFeedback: (WakeMood?, String) -> Void

    @State private var note: String

    init(session: WakeSession, sessions: [WakeSession], onDone: @escaping () -> Void, onFeedback: @escaping (WakeMood?, String) -> Void) {
        self.session = session
        self.sessions = sessions
        self.onDone = onDone
        self.onFeedback = onFeedback
        _note = State(initialValue: session.note)
    }

    var body: some View {
        ZStack {
            SuccessMorningBackdrop(dimmed: session.emergencyClosed)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                successHero

                Spacer()

                Button {
                    onFeedback(session.mood, note)
                    onDone()
                } label: {
                    PrimaryCapsuleLabel(title: session.emergencyClosed ? "知道了" : "完成")
                        .frame(maxWidth: 320)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)
                .padding(.bottom, 56)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var successHero: some View {
        VStack(spacing: 12) {
            Text(formattedCompletedTime)
                .font(.clock(64))
                .monospacedDigit()
                .foregroundStyle(Bedside.text.opacity(0.92))

            Text(session.emergencyClosed ? "已紧急关闭" : "起床成功")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Bedside.text)

            Text(session.emergencyClosed ? "这次先算赖床赢了" : "今天没有被床封印")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(session.emergencyClosed ? Bedside.red : Bedside.subtext)
                .multilineTextAlignment(.center)

            summaryLine
                .padding(.top, 10)
        }
        .frame(maxWidth: 390)
        .padding(.horizontal, 28)
        .padding(.top, 120)
    }

    private var emergencyMark: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 54, weight: .semibold))
            .foregroundStyle(Bedside.red)
            .frame(height: 122)
    }

    private var breathingLine: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.08))
                .frame(width: 164, height: 2)

            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.clear, Bedside.amber.opacity(session.emergencyClosed ? 0 : 0.95), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 164, height: 2)
                .blur(radius: 0.5)
        }
    }

    private var summaryLine: some View {
        HStack(spacing: 7) {
            Text(challengeResultText)
            Text("·")
                .foregroundStyle(Bedside.dim)
            Text("用时 \(formattedDuration)")
            Text("·")
                .foregroundStyle(Bedside.dim)
            Text("连续 \(currentStreak) 天")
        }
        .font(.system(size: 13, weight: .regular))
        .foregroundStyle(Bedside.subtext)
        .lineLimit(1)
        .minimumScaleFactor(0.68)
    }

    private var formattedCompletedTime: String {
        SuccessDateFormatters.completedTime.string(from: session.completedAt)
    }

    private var formattedDuration: String {
        let minutes = session.durationSeconds / 60
        let seconds = session.durationSeconds % 60
        if minutes > 0 {
            return "\(minutes)分\(seconds)秒"
        }
        return "\(seconds)秒"
    }

    private var challengeSummary: String {
        if session.challengeType == .math {
            return "\(session.challengeType.rawValue)（\(session.mathDifficulty.rawValue)）"
        }
        return session.challengeType.rawValue
    }

    private var challengeResultText: String {
        if session.emergencyClosed {
            return "紧急关闭"
        }
        return "\(challengeSummary)通过"
    }

    private var completedSessions: [WakeSession] {
        WakeSessionStats.completedSessions(sessions, including: session)
    }

    private var currentStreak: Int {
        WakeSessionStats.currentStreak(sessions: completedSessions, endingOn: session.completedAt)
    }

    private var bestStreak: Int {
        WakeSessionStats.bestStreak(sessions: completedSessions)
    }
}

/// 抽象暖色日出：地平线下升起的一轮柔光，没有具象插画。
private struct SuccessMorningBackdrop: View {
    var dimmed: Bool = false

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let horizon = height * 0.62

            ZStack(alignment: .top) {
                LinearGradient(
                    colors: [
                        Bedside.bg,
                        Color(hex: "1E1610"),
                        Color(hex: dimmed ? "2A1E16" : "4A2C18")
                    ],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.62)
                )

                // 太阳光晕
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "F6C98A").opacity(dimmed ? 0.25 : 0.85),
                                Bedside.accent.opacity(dimmed ? 0.15 : 0.45),
                                Color(hex: "C8643A").opacity(dimmed ? 0.06 : 0.18),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: width * 0.75
                        )
                    )
                    .frame(width: width * 1.5, height: width * 1.5)
                    .position(x: width / 2, y: horizon + width * 0.08)

                // 太阳本体
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "FBE3BC"), Color(hex: "F0B36E")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: width * 0.42, height: width * 0.42)
                    .opacity(dimmed ? 0.3 : 0.95)
                    .position(x: width / 2, y: horizon + width * 0.06)

                // 地平线以下：暖色倒影慢慢沉进底色
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: dimmed ? "241A13" : "3A2416"),
                                Color(hex: "1A130E"),
                                Bedside.bg
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: height - horizon)
                    .overlay(alignment: .top) {
                        LinearGradient(
                            colors: [.clear, Color(hex: "F6C98A").opacity(dimmed ? 0.12 : 0.45), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(height: 0.5)
                    }
                    .position(x: width / 2, y: horizon + (height - horizon) / 2)
            }
        }
    }
}

#Preview {
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
}
