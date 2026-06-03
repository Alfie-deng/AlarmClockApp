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

    @State private var selectedMood: WakeMood?
    @State private var note: String

    init(session: WakeSession, sessions: [WakeSession], onDone: @escaping () -> Void, onFeedback: @escaping (WakeMood?, String) -> Void) {
        self.session = session
        self.sessions = sessions
        self.onDone = onDone
        self.onFeedback = onFeedback
        _selectedMood = State(initialValue: session.mood)
        _note = State(initialValue: session.note)
    }

    var body: some View {
        ZStack {
            SuccessMorningBackdrop()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 68)

                successHero

                Spacer()

                Button {
                    onFeedback(selectedMood, note)
                    onDone()
                } label: {
                    Text(session.emergencyClosed ? "知道了" : "完成")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.82))
                        .frame(maxWidth: 320)
                        .padding(.vertical, 15)
                }
                .buttonStyle(.plain)
                .background(
                    Capsule(style: .continuous)
                        .fill(LinearGradient(colors: [Bedside.amber, Bedside.accent], startPoint: .topLeading, endPoint: .bottomTrailing))
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var successHero: some View {
        VStack(spacing: 28) {
            VStack(spacing: 10) {
                Text(session.emergencyClosed ? "已紧急关闭" : "起床成功")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(session.emergencyClosed ? Bedside.red : Bedside.text)

                Text(session.emergencyClosed ? "这次先算赖床赢了" : "今天没有被床封印")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(session.emergencyClosed ? Bedside.red.opacity(0.86) : Bedside.amber)
                    .multilineTextAlignment(.center)
                    .shadow(color: Bedside.accent.opacity(session.emergencyClosed ? 0 : 0.30), radius: 14)
            }

            if session.emergencyClosed {
                emergencyMark
            } else {
                Color.clear
                    .frame(height: 330)
            }

            if session.emergencyClosed {
                summaryLine
                    .padding(.top, 0)
            }
        }
        .frame(maxWidth: 390)
        .padding(.horizontal, 28)
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
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Bedside.subtext)
        .lineLimit(1)
        .minimumScaleFactor(0.68)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.18))
                .overlay(Capsule(style: .continuous).stroke(Bedside.sep.opacity(0.72), lineWidth: 0.7))
        )
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

private struct SuccessMorningBackdrop: View {
    var body: some View {
        ZStack {
            Image("SuccessGeneratedBackground")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack {
                LinearGradient(
                    colors: [
                        Bedside.bg.opacity(0.92),
                        Bedside.bg.opacity(0.58),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 330)
                Spacer()
            }

            LinearGradient(
                colors: [
                    .clear,
                    .clear,
                    Bedside.bg.opacity(0.34),
                    Bedside.bg
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .background(Bedside.bg)
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
