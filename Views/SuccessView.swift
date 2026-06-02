import SwiftUI

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
            RingingAmbientBackground()
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    sunBadge
                        .padding(.top, 44)
                    
                    VStack(spacing: 8) {
                        Text(session.emergencyClosed ? "已紧急关闭" : "起床成功！")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(session.emergencyClosed ? Bedside.red : Bedside.amber)
                        Text(session.emergencyClosed ? "今天先记一笔，下次别让闹钟赢。" : "新的一天，继续加油！")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Bedside.subtext)
                    }
                    
                    resultCard
                    moodCard
                    streakCard
                    
                    Button {
                        onFeedback(selectedMood, note)
                        onDone()
                    } label: {
                        Text("完成")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.82))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(LinearGradient(colors: [Bedside.amber, Bedside.accent], startPoint: .topLeading, endPoint: .bottomTrailing))
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private var sunBadge: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Bedside.amber, Bedside.accent.opacity(0.78), Bedside.accent.opacity(0.18)],
                        center: .center,
                        startRadius: 12,
                        endRadius: 74
                    )
                )
                .frame(width: 118, height: 118)
                .shadow(color: Bedside.accent.opacity(0.48), radius: 28)
            
            Text(session.emergencyClosed ? "!" : "☀")
                .font(.system(size: 54, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.62))
        }
    }
    
    private var resultCard: some View {
        VStack(spacing: 14) {
            resultRow("起床时间", value: formattedCompletedTime)
            resultRow("本次挑战", value: challengeSummary)
            resultRow("用时", value: formattedDuration)
        }
        .padding(18)
        .background { LiquidGlassPanel(radius: 18, style: .card) }
    }
    
    private var moodCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("今天的感觉怎么样？")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Bedside.subtext)
            
            HStack(spacing: 12) {
                ForEach(WakeMood.allCases) { mood in
                    Button {
                        selectedMood = mood
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: mood.icon)
                                .font(.system(size: 28, weight: .medium))
                                .foregroundStyle(selectedMood == mood ? Bedside.accent : Bedside.subtext)
                            Text(mood.rawValue)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(selectedMood == mood ? Bedside.amber : Bedside.subtext)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill((selectedMood == mood ? Bedside.accent : .white).opacity(selectedMood == mood ? 0.13 : 0.045))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke((selectedMood == mood ? Bedside.accent : .white).opacity(selectedMood == mood ? 0.28 : 0.08), lineWidth: 0.7)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("今天的感觉...")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Bedside.subtext)
                TextField("记录一下你的想法吧...", text: $note, axis: .vertical)
                    .lineLimit(2...4)
                    .font(.system(size: 14))
                    .foregroundStyle(Bedside.text)
                    .padding(13)
                    .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(18)
        .background { LiquidGlassPanel(radius: 18, style: .card) }
    }
    
    private var streakCard: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("🔥 连续起床")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Bedside.amber)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(currentStreak)")
                        .font(.system(size: 46, weight: .light, design: .rounded))
                        .foregroundStyle(Bedside.amber)
                    Text("天")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Bedside.subtext)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Rectangle()
                .fill(Bedside.sep)
                .frame(width: 0.7, height: 64)
            
            VStack(alignment: .trailing, spacing: 6) {
                Text("历史最长")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Bedside.subtext)
                Text(bestStreak > 0 ? "\(bestStreak)天" : "待累计")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Bedside.amber)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(18)
        .background { LiquidGlassPanel(radius: 18, style: .card) }
    }
    
    private func resultRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Bedside.subtext)
            Spacer()
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Bedside.amber)
        }
    }
    
    private var formattedCompletedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: session.completedAt)
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
