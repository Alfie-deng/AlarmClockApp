import SwiftUI

struct StatsView: View {
    @EnvironmentObject var mgr: AlarmManager

    private struct ChallengeSummary: Identifiable {
        let type: ChallengeType
        let count: Int
        let averageDuration: Int?
        let barRatio: Double

        var id: ChallengeType { type }
    }

    private struct WakePersona {
        let title: String
        let subtitle: String
        let detail: String
        let symbol: String
    }

    fileprivate struct WakeTimePoint: Identifiable {
        let id = UUID()
        let dayLabel: String
        let minutes: Int?
    }

    private var completedSessions: [WakeSession] {
        WakeSessionStats.completedSessions(mgr.wakeSessions)
    }

    private var emergencySessions: [WakeSession] {
        mgr.wakeSessions.filter(\.emergencyClosed)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BedsideAmbientBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        BedsideTopBar(title: "起床人格")
                            .padding(.horizontal, -20)

                        wakePersonaCard
                        resultSummaryCard
                        wakeRegularityCard
                        challengePerformanceCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 0)
                    .padding(.bottom, 84)
                }
            }
        }
    }


    // MARK: - 起床人格
    private var wakePersonaCard: some View {
        let persona = wakePersona
        return VStack(alignment: .leading, spacing: 6) {
            Text(persona.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Bedside.amber)
            Text(persona.subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Bedside.subtext)
            Text(persona.detail)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Bedside.subtext)
                .lineLimit(2)
                .minimumScaleFactor(0.84)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
        .padding(.top, 2)
        .padding(.bottom, 4)
    }

    // MARK: - 起床结果
    private var resultSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("当前连续")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Bedside.subtext)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(currentStreak)")
                            .font(.system(size: 64, weight: .light, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Bedside.amber)
                            .shadow(color: Bedside.accent.opacity(0.28), radius: 12)
                        Text("天")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Bedside.subtext)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text("本周完成")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Bedside.subtext)
                    Text("\(weekSuccessCount)/\(weekTargetDayCount)")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Bedside.text)
                    Text(weekRemainingText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Bedside.dim)
                }
            }

            ProgressView(value: weekProgress)
                .tint(Bedside.accent)
                .scaleEffect(x: 1, y: 1.22, anchor: .center)

            HStack(spacing: 8) {
                compactMetric(title: "紧急关闭", value: "\(emergencySessions.count) 次")
                compactMetric(title: "最长连续", value: "\(bestStreak) 天")
            }
        }
        .padding(18)
        .background { statsFlatPanel(radius: 24, highlighted: true) }
    }

    private func compactMetric(title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Bedside.dim)
            Spacer(minLength: 4)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Bedside.text)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.045))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Bedside.sep, lineWidth: 0.7))
        )
    }

    // MARK: - 起床规律
    private var wakeRegularityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("起床节奏")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Bedside.text)
                Text(wakeRegularitySubtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Bedside.subtext)
            }

            WakeTimeLineChart(points: wakeTimePoints)
                .frame(height: 78)

            HStack(spacing: 8) {
                regularityPill(text: wakeVolatilityText)
                regularityPill(text: wakeStabilityText)
            }
        }
        .padding(16)
        .background { statsFlatPanel(radius: 22) }
    }

    private func regularityPill(text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Bedside.subtext)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.045))
                    .overlay(Capsule().stroke(Bedside.sep, lineWidth: 0.7))
            )
    }

    // MARK: - 挑战表现
    private var challengePerformanceCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            VStack(alignment: .leading, spacing: 4) {
                Text("挑战表现")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Bedside.text)
                Text("不同挑战的使用次数和平均完成时间")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Bedside.subtext)
            }

            VStack(spacing: 8) {
                ForEach(challengeSummaries) { item in
                    challengeRow(item)
                }
            }

            regularityPill(text: "\(fastestChallengeText) · \(mostUsedChallengeText)")
        }
        .padding(16)
        .background { statsFlatPanel(radius: 22) }
    }

    private func challengeRow(_ item: ChallengeSummary) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: item.type.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(item.count > 0 ? Bedside.accent : Bedside.dim)
                        .frame(width: 20)
                    Text(item.type.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Bedside.text)
                        .frame(width: 52, alignment: .leading)
                }

                Spacer(minLength: 8)

                Text("\(item.count) 次")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(item.count > 0 ? Bedside.accent : Bedside.dim)
                    .frame(width: 48, alignment: .trailing)

                Text(item.averageDuration.map(durationText) ?? "暂无")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Bedside.subtext)
                    .frame(width: 68, alignment: .trailing)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.06))
                    Capsule(style: .continuous)
                        .fill(Bedside.accent)
                        .frame(width: max(item.count > 0 ? 14 : 0, proxy.size.width * item.barRatio))
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.035))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Bedside.sep.opacity(0.75), lineWidth: 0.7))
        )
    }

    @ViewBuilder
    private func statsFlatPanel(radius: CGFloat, highlighted: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(hex: "121923").opacity(0.86), Color(hex: "111014").opacity(0.78)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Bedside.accent.opacity(highlighted ? 0.95 : 0.58), lineWidth: highlighted ? 0.9 : 0.72)
            )
    }

    // MARK: - Derived data
    private var wakePersona: WakePersona {
        if emergencySessions.count >= 3 {
            return WakePersona(
                title: "紧急关闭艺术家",
                subtitle: "你和关闭按钮熟得像老同事",
                detail: "紧急关闭 \(emergencySessions.count) 次，系统已开始怀疑你的清醒诚意。",
                symbol: "exclamationmark.triangle.fill"
            )
        }

        if currentStreak >= 5 {
            return WakePersona(
                title: "晨间战士",
                subtitle: "闹钟响起，你负责执行",
                detail: "当前连续 \(currentStreak) 天，已经不像人类，像早晨的纪律机器。",
                symbol: "sunrise.fill"
            )
        }

        if weekSuccessCount >= weekTargetDayCount, weekTargetDayCount >= 3 {
            return WakePersona(
                title: "准点人类",
                subtitle: "本周目前没给被窝机会",
                detail: "本周已发生日期全部完成，继续保持，别让周末出来捣乱。",
                symbol: "checkmark.seal.fill"
            )
        }

        if wakeVolatilityMinutes > 35 {
            return WakePersona(
                title: "作息游牧民",
                subtitle: "你的起床时间正在四处迁徙",
                detail: "近 7 日起床波动约 \(wakeVolatilityMinutes) 分钟，规律性还有救，但别拖成考古项目。",
                symbol: "point.topleft.down.curvedto.point.bottomright.up"
            )
        }

        if let mostUsed = challengeSummaries.max(by: { $0.count < $1.count }), mostUsed.count > 0 {
            return WakePersona(
                title: "\(mostUsed.type.rawValue)求生者",
                subtitle: "最常靠它把自己从床上捞出来",
                detail: "\(mostUsed.type.rawValue)已完成 \(mostUsed.count) 次，当前连续 \(currentStreak) 天。",
                symbol: mostUsed.type.icon
            )
        }

        return WakePersona(
            title: "起床观察对象",
            subtitle: "样本还少，系统先不下狠手",
            detail: "完成几次挑战后，这里会给你一个更精准也更欠揍的称号。",
            symbol: "person.crop.circle.badge.questionmark"
        )
    }

    private var currentStreak: Int {
        WakeSessionStats.currentStreak(sessions: completedSessions, endingOn: Date())
    }

    private var bestStreak: Int {
        WakeSessionStats.bestStreak(sessions: completedSessions)
    }

    private var weekSuccessCount: Int {
        weekCompletedDays.count
    }

    private var weekTargetDayCount: Int {
        weekTargetDays.count
    }

    private var weekProgress: Double {
        guard weekTargetDayCount > 0 else { return 0 }
        return min(Double(weekSuccessCount) / Double(weekTargetDayCount), 1)
    }

    private var weekRemainingText: String {
        let remaining = max(0, weekTargetDayCount - weekSuccessCount)
        return remaining > 0 ? "还差 \(remaining) 天" : "本周达标"
    }

    private var weekTargetDays: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let startOffset = 2 - weekday
        let monday = calendar.date(byAdding: .day, value: startOffset, to: today) ?? today
        return (0..<5).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: monday)
        }
    }

    private var weekCompletedDays: Set<Date> {
        let calendar = Calendar.current
        let targets = Set(weekTargetDays)
        return Set(completedSessions.map { calendar.startOfDay(for: $0.completedAt) }.filter { targets.contains($0) })
    }

    private var wakeTimePoints: [WakeTimePoint] {
        let calendar = Calendar.current
        let symbols = ["日", "一", "二", "三", "四", "五", "六"]
        return weekTargetDays.map { day in
            let label = symbols[calendar.component(.weekday, from: day) - 1]
            let session = completedSessions
                .filter { calendar.isDate($0.completedAt, inSameDayAs: day) }
                .sorted { $0.completedAt < $1.completedAt }
                .first
            return WakeTimePoint(dayLabel: label, minutes: session.map(minutesAfterMidnight))
        }
    }

    private var wakeMinutes: [Int] {
        wakeTimePoints.compactMap(\.minutes)
    }

    private var wakeRegularitySubtitle: String {
        guard !wakeMinutes.isEmpty else { return "完成一次挑战后生成起床规律" }
        return "平均 \(timeText(averageWakeMinutes)) · 最早 \(timeText(wakeMinutes.min() ?? averageWakeMinutes)) · 最晚 \(timeText(wakeMinutes.max() ?? averageWakeMinutes))"
    }

    private var averageWakeMinutes: Int {
        guard !wakeMinutes.isEmpty else { return 0 }
        return wakeMinutes.reduce(0, +) / wakeMinutes.count
    }

    private var wakeVolatilityMinutes: Int {
        guard wakeMinutes.count > 1 else { return 0 }
        let average = Double(wakeMinutes.reduce(0, +)) / Double(wakeMinutes.count)
        let totalDeviation = wakeMinutes.map { abs(Double($0) - average) }.reduce(0, +)
        return Int((totalDeviation / Double(wakeMinutes.count)).rounded())
    }

    private var wakeVolatilityText: String {
        wakeMinutes.count > 1 ? "波动 \(wakeVolatilityMinutes) 分钟" : "波动待累计"
    }

    private var wakeStabilityText: String {
        guard wakeMinutes.count > 1 else { return "稳定度待累计" }
        switch wakeVolatilityMinutes {
        case 0...15: return "稳定度：很稳"
        case 16...35: return "稳定度：较稳定"
        default: return "稳定度：波动较大"
        }
    }

    private var challengeSummaries: [ChallengeSummary] {
        let supported = ChallengeType.supportedCases
        let maxCount = max(1, supported.map { type in completedSessions.filter { $0.challengeType == type }.count }.max() ?? 1)
        return supported.map { type in
            let sessions = completedSessions.filter { $0.challengeType == type }
            let avg = sessions.isEmpty ? nil : sessions.map(\.durationSeconds).reduce(0, +) / sessions.count
            return ChallengeSummary(
                type: type,
                count: sessions.count,
                averageDuration: avg,
                barRatio: Double(sessions.count) / Double(maxCount)
            )
        }
    }

    private var fastestChallengeText: String {
        let fastest = challengeSummaries
            .compactMap { item -> (ChallengeType, Int)? in item.averageDuration.map { (item.type, $0) } }
            .min { $0.1 < $1.1 }
        if let fastest { return "最快：\(fastest.0.rawValue) \(durationText(fastest.1))" }
        return "最快：待累计"
    }

    private var mostUsedChallengeText: String {
        let mostUsed = challengeSummaries.max { $0.count < $1.count }
        if let mostUsed, mostUsed.count > 0 { return "最常用：\(mostUsed.type.rawValue)" }
        return "最常用：待累计"
    }

    private func minutesAfterMidnight(_ session: WakeSession) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: session.completedAt)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func timeText(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    private func durationText(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        if minutes > 0 { return "\(minutes)分\(seconds)秒" }
        return "\(seconds)秒"
    }
}

private struct WakeTimeLineChart: View {
    let points: [StatsView.WakeTimePoint]

    private var validMinutes: [Int] { points.compactMap(\.minutes) }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                ZStack {
                    VStack(spacing: 0) {
                        ForEach(0..<3, id: \.self) { _ in
                            Rectangle()
                                .fill(Bedside.sep.opacity(0.72))
                                .frame(height: 0.7)
                            Spacer()
                        }
                    }
                    .padding(.vertical, 8)

                    if validMinutes.isEmpty {
                        Text("暂无起床记录")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Bedside.dim)
                    } else {
                        chartPath(size: proxy.size)
                            .stroke(Bedside.accent, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                        ForEach(Array(points.enumerated()), id: \.element.id) { _, point in
                            if point.minutes != nil {
                                Circle()
                                    .fill(Bedside.accent)
                                    .frame(width: 10, height: 10)
                                    .position(position(for: point, size: proxy.size))
                            }
                        }
                    }
                }
            }

            HStack {
                ForEach(points) { point in
                    Text(point.dayLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Bedside.dim)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func chartPath(size: CGSize) -> Path {
        var path = Path()
        var didMove = false
        for point in points where point.minutes != nil {
            let pos = position(for: point, size: size)
            if didMove {
                path.addLine(to: pos)
            } else {
                path.move(to: pos)
                didMove = true
            }
        }
        return path
    }

    private func position(for point: StatsView.WakeTimePoint, size: CGSize) -> CGPoint {
        guard let index = points.firstIndex(where: { $0.id == point.id }) else { return .zero }
        let minMinute = validMinutes.min() ?? 420
        let maxMinute = validMinutes.max() ?? 480
        let range = max(30, maxMinute - minMinute)
        let x = points.count <= 1 ? size.width / 2 : CGFloat(index) / CGFloat(points.count - 1) * size.width
        let normalized = CGFloat((point.minutes ?? minMinute) - minMinute) / CGFloat(range)
        let y = 12 + normalized * max(1, size.height - 24)
        return CGPoint(x: x, y: y)
    }
}

#Preview { StatsView().environmentObject(AlarmManager()) }
