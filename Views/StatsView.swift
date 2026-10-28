import SwiftUI

struct StatsView: View {
    let sessions: [WakeSession]

    init(sessions: [WakeSession] = []) {
        self.sessions = sessions
    }

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
        let id: Int
        let dayLabel: String
        let minutes: Int?
    }

    private struct StatsSnapshot {
        let completedSessions: [WakeSession]
        let emergencyCount: Int
        let currentStreak: Int
        let bestStreak: Int
        let weekSuccessCount: Int
        let weekTargetDayCount: Int
        let wakeTimePoints: [WakeTimePoint]
        let wakeMinutes: [Int]
        let wakeRegularitySubtitle: String
        let wakeVolatilityMinutes: Int
        let wakeVolatilityText: String
        let wakeStabilityText: String
        let challengeSummaries: [ChallengeSummary]
        let fastestChallengeText: String
        let mostUsedChallengeText: String
        let persona: WakePersona

        init(sessions: [WakeSession], now: Date = Date(), calendar: Calendar = .current) {
            let completed = WakeSessionStats.completedSessions(sessions)
            let emergencyCount = sessions.filter(\.emergencyClosed).count
            let currentStreak = WakeSessionStats.currentStreak(sessions: completed, endingOn: now)
            let bestStreak = WakeSessionStats.bestStreak(sessions: completed)
            let weekTargetDays = Self.makeWeekTargetDays(now: now, calendar: calendar)
            let targetSet = Set(weekTargetDays)
            let completedDays = Set(completed.map { calendar.startOfDay(for: $0.completedAt) }.filter { targetSet.contains($0) })
            let rhythmSessions = completed.filter { Self.isRhythmEligible($0, calendar: calendar) }
            let wakeTimePoints = Self.makeWakeTimePoints(days: weekTargetDays, sessions: rhythmSessions, calendar: calendar)
            let wakeMinutes = wakeTimePoints.compactMap(\.minutes)
            let averageWakeMinutes = wakeMinutes.isEmpty ? 0 : wakeMinutes.reduce(0, +) / wakeMinutes.count
            let volatility = Self.wakeVolatilityMinutes(wakeMinutes)
            let challengeSummaries = Self.makeChallengeSummaries(completedSessions: completed)
            let fastestChallengeText = Self.fastestChallengeText(challengeSummaries)
            let mostUsedChallengeText = Self.mostUsedChallengeText(challengeSummaries)
            let regularitySubtitle: String
            if wakeMinutes.isEmpty {
                regularitySubtitle = completed.isEmpty ? "完成一次挑战后生成起床规律" : "早晨记录不足，暂不计算作息波动"
            } else {
                regularitySubtitle = "平均 \(Self.timeText(averageWakeMinutes)) · 最早 \(Self.timeText(wakeMinutes.min() ?? averageWakeMinutes)) · 最晚 \(Self.timeText(wakeMinutes.max() ?? averageWakeMinutes))"
            }
            let stability: String
            if wakeMinutes.count <= 1 {
                stability = "稳定度待累计"
            } else {
                switch volatility {
                case 0...15: stability = "稳定度：很稳"
                case 16...35: stability = "稳定度：较稳定"
                default: stability = "稳定度：波动较大"
                }
            }

            self.completedSessions = completed
            self.emergencyCount = emergencyCount
            self.currentStreak = currentStreak
            self.bestStreak = bestStreak
            self.weekSuccessCount = completedDays.count
            self.weekTargetDayCount = weekTargetDays.count
            self.wakeTimePoints = wakeTimePoints
            self.wakeMinutes = wakeMinutes
            self.wakeRegularitySubtitle = regularitySubtitle
            self.wakeVolatilityMinutes = volatility
            self.wakeVolatilityText = wakeMinutes.count > 1 ? "波动 \(volatility) 分钟" : "波动待累计"
            self.wakeStabilityText = stability
            self.challengeSummaries = challengeSummaries
            self.fastestChallengeText = fastestChallengeText
            self.mostUsedChallengeText = mostUsedChallengeText
            self.persona = Self.makeWakePersona(
                emergencyCount: emergencyCount,
                currentStreak: currentStreak,
                weekSuccessCount: completedDays.count,
                weekTargetDayCount: weekTargetDays.count,
                wakeVolatilityMinutes: volatility,
                challengeSummaries: challengeSummaries
            )
        }

        private static func makeWeekTargetDays(now: Date, calendar: Calendar) -> [Date] {
            let today = calendar.startOfDay(for: now)
            let weekday = calendar.component(.weekday, from: today)
            let startOffset = 2 - weekday
            let monday = calendar.date(byAdding: .day, value: startOffset, to: today) ?? today
            return (0..<5).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
        }

        private static func makeWakeTimePoints(days: [Date], sessions: [WakeSession], calendar: Calendar) -> [WakeTimePoint] {
            let symbols = ["日", "一", "二", "三", "四", "五", "六"]
            let sessionsByDay = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.completedAt) }
            return days.enumerated().map { index, day in
                let label = symbols[calendar.component(.weekday, from: day) - 1]
                let session = sessionsByDay[calendar.startOfDay(for: day)]?.min { $0.completedAt < $1.completedAt }
                return WakeTimePoint(id: index, dayLabel: label, minutes: session.map(minutesAfterMidnight))
            }
        }

        private static func isRhythmEligible(_ session: WakeSession, calendar: Calendar) -> Bool {
            let hour = calendar.component(.hour, from: session.completedAt)
            return (4...12).contains(hour)
        }

        private static func makeChallengeSummaries(completedSessions: [WakeSession]) -> [ChallengeSummary] {
            let supported = ChallengeType.supportedCases
            let grouped = Dictionary(grouping: completedSessions, by: \.challengeType)
            let maxCount = max(1, supported.map { grouped[$0]?.count ?? 0 }.max() ?? 1)
            return supported.map { type in
                let sessions = grouped[type] ?? []
                let avg = sessions.isEmpty ? nil : sessions.map(\.durationSeconds).reduce(0, +) / sessions.count
                return ChallengeSummary(
                    type: type,
                    count: sessions.count,
                    averageDuration: avg,
                    barRatio: Double(sessions.count) / Double(maxCount)
                )
            }
        }

        private static func fastestChallengeText(_ summaries: [ChallengeSummary]) -> String {
            let fastest = summaries
                .compactMap { item -> (ChallengeType, Int)? in item.averageDuration.map { (item.type, $0) } }
                .min { $0.1 < $1.1 }
            if let fastest { return "最快：\(fastest.0.rawValue) \(durationText(fastest.1))" }
            return "最快：待累计"
        }

        private static func mostUsedChallengeText(_ summaries: [ChallengeSummary]) -> String {
            let mostUsed = summaries.max { $0.count < $1.count }
            if let mostUsed, mostUsed.count > 0 { return "最常用：\(mostUsed.type.rawValue)" }
            return "最常用：待累计"
        }

        private static func makeWakePersona(
            emergencyCount: Int,
            currentStreak: Int,
            weekSuccessCount: Int,
            weekTargetDayCount: Int,
            wakeVolatilityMinutes: Int,
            challengeSummaries: [ChallengeSummary]
        ) -> WakePersona {
            if emergencyCount >= 3 {
                return WakePersona(title: "紧急关闭艺术家", subtitle: "你和关闭按钮熟得像老同事", detail: "紧急关闭 \(emergencyCount) 次，系统已开始怀疑你的清醒诚意。", symbol: "exclamationmark.triangle.fill")
            }
            if currentStreak >= 5 {
                return WakePersona(title: "晨间战士", subtitle: "闹钟响起，你负责执行", detail: "当前连续 \(currentStreak) 天，已经不像人类，像早晨的纪律机器。", symbol: "sunrise.fill")
            }
            if weekSuccessCount >= weekTargetDayCount, weekTargetDayCount >= 3 {
                return WakePersona(title: "准点人类", subtitle: "本周目前没给被窝机会", detail: "本周已发生日期全部完成，继续保持，别让周末出来捣乱。", symbol: "checkmark.seal.fill")
            }
            if wakeVolatilityMinutes > 35 {
                return WakePersona(title: "作息游牧民", subtitle: "你的起床时间正在四处迁徙", detail: "近 7 日起床波动约 \(wakeVolatilityMinutes) 分钟，规律性还有救，但别拖成考古项目。", symbol: "point.topleft.down.curvedto.point.bottomright.up")
            }
            if let mostUsed = challengeSummaries.max(by: { $0.count < $1.count }), mostUsed.count > 0 {
                return personaForMostUsedChallenge(mostUsed.type, count: mostUsed.count, currentStreak: currentStreak)
            }
            return WakePersona(title: "起床观察对象", subtitle: "样本还少，系统先不下狠手", detail: "完成几次挑战后，这里会给你一个更精准也更欠揍的称号。", symbol: "person.crop.circle.badge.questionmark")
        }

        private static func personaForMostUsedChallenge(_ type: ChallengeType, count: Int, currentStreak: Int) -> WakePersona {
            switch type {
            case .math:
                return WakePersona(
                    title: "晨间算术师",
                    subtitle: "先把脑子点亮，再和被窝谈判",
                    detail: "数学题已通关 \(count) 次，当前连续 \(currentStreak) 天。清醒这件事，先从算对开始。",
                    symbol: type.icon
                )
            case .shake:
                return WakePersona(
                    title: "被窝拆迁队",
                    subtitle: "把赖床摇散，把清醒摇回来",
                    detail: "摇手机已完成 \(count) 次，当前连续 \(currentStreak) 天。每天早上先给被窝来点工程震动。",
                    symbol: type.icon
                )
            case .photo:
                return WakePersona(
                    title: "清醒取证员",
                    subtitle: "拍到证据，赖床就不能抵赖",
                    detail: "拍照已完成 \(count) 次，当前连续 \(currentStreak) 天。赖床现场已经被你多次取证。",
                    symbol: type.icon
                )
            case .speak:
                return WakePersona(
                    title: "起床宣誓官",
                    subtitle: "嘴先醒，身体就别继续装死",
                    detail: "念语句已完成 \(count) 次，当前连续 \(currentStreak) 天。嘴醒了，身体别装死。",
                    symbol: type.icon
                )
            case .memory:
                return WakePersona(
                    title: "记忆开机员",
                    subtitle: "用短路边缘唤醒大脑",
                    detail: "记忆挑战已完成 \(count) 次，当前连续 \(currentStreak) 天。",
                    symbol: type.icon
                )
            }
        }

        private static func minutesAfterMidnight(_ session: WakeSession) -> Int {
            let components = Calendar.current.dateComponents([.hour, .minute], from: session.completedAt)
            return (components.hour ?? 0) * 60 + (components.minute ?? 0)
        }

        private static func wakeVolatilityMinutes(_ wakeMinutes: [Int]) -> Int {
            guard wakeMinutes.count > 1 else { return 0 }
            let average = Double(wakeMinutes.reduce(0, +)) / Double(wakeMinutes.count)
            let totalDeviation = wakeMinutes.map { abs(Double($0) - average) }.reduce(0, +)
            return Int((totalDeviation / Double(wakeMinutes.count)).rounded())
        }

        static func timeText(_ minutes: Int) -> String {
            String(format: "%02d:%02d", minutes / 60, minutes % 60)
        }

        static func durationText(_ seconds: Int) -> String {
            let minutes = seconds / 60
            let seconds = seconds % 60
            if minutes > 0 { return "\(minutes)分\(seconds)秒" }
            return "\(seconds)秒"
        }
    }

    private var snapshot: StatsSnapshot {
        StatsSnapshot(sessions: sessions)
    }

    var body: some View {
        let snapshot = snapshot
        return NavigationStack {
            ZStack {
                BedsideAmbientBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        statsHeader
                        battleHeroCard(snapshot)
                        wakeRhythmReportCard(snapshot)
                        challengeRankCard(snapshot)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 116)
                }
            }
        }
    }

    private var statsHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("统计")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Bedside.text)
            Text("你和被窝的交手记录")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Bedside.subtext)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.vertical, 12)
    }

    private func battleHeroCard(_ snapshot: StatsSnapshot) -> some View {
        let persona = snapshot.persona
        return VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Label("起床人格", systemImage: persona.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Bedside.accent)

                Text(persona.title)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Bedside.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(persona.subtitle)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Bedside.subtext)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(Bedside.sep)
                .frame(height: 0.5)

            HStack(spacing: 0) {
                heroSummaryMetric(title: "本周完成", value: "\(snapshot.weekSuccessCount)", unit: "/\(snapshot.weekTargetDayCount)")
                metricDivider
                heroSummaryMetric(title: "最佳纪录", value: "\(snapshot.bestStreak)", unit: "天")
                metricDivider
                heroSummaryMetric(title: "紧急关闭", value: "\(snapshot.emergencyCount)", unit: "次")
            }
        }
        .padding(22)
        .background { LiquidGlassPanel(radius: 24, style: .card) }
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(Bedside.sep)
            .frame(width: 0.5, height: 36)
    }

    private func heroSummaryMetric(title: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.clock(32))
                    .monospacedDigit()
                    .foregroundStyle(Bedside.text)
                Text(unit)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Bedside.subtext)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            Text(title)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Bedside.subtext)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 14)
    }

    private func wakeRhythmReportCard(_ snapshot: StatsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("起床节奏")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Bedside.text)
                Text(snapshot.wakeRegularitySubtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Bedside.subtext)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            WakeTimeLineChart(points: snapshot.wakeTimePoints)
                .frame(height: 86)

            HStack(spacing: 0) {
                reportBadge(title: "波动", value: snapshot.wakeVolatilityText.replacingOccurrences(of: "波动 ", with: ""))
                reportBadge(title: "稳定度", value: snapshot.wakeStabilityText.replacingOccurrences(of: "稳定度：", with: ""))
            }
        }
        .padding(20)
        .background { LiquidGlassPanel(radius: 24, style: .card) }
    }

    private func challengeRankCard(_ snapshot: StatsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("挑战排行")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Bedside.text)
                Text("\(snapshot.fastestChallengeText) · \(snapshot.mostUsedChallengeText)")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Bedside.subtext)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .padding(.bottom, 4)

            ForEach(Array(snapshot.challengeSummaries.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Rectangle()
                        .fill(Bedside.sep)
                        .frame(height: 0.5)
                        .padding(.leading, 36)
                }
                challengeBattleRow(item)
            }
        }
        .padding(20)
        .background { LiquidGlassPanel(radius: 24, style: .card) }
    }

    private func challengeBattleRow(_ item: ChallengeSummary) -> some View {
        HStack(spacing: 14) {
            Image(systemName: item.type.icon)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(item.count > 0 ? Bedside.accent : Bedside.dim)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.type.rawValue)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Bedside.text)
                    Spacer()
                    Text("\(item.count) 次")
                        .font(.system(size: 13, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(item.count > 0 ? Bedside.text : Bedside.dim)
                    Text(item.averageDuration.map(StatsSnapshot.durationText) ?? "—")
                        .font(.system(size: 13, weight: .regular))
                        .monospacedDigit()
                        .foregroundStyle(Bedside.subtext)
                        .frame(width: 58, alignment: .trailing)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.06))
                        Capsule(style: .continuous)
                            .fill(Bedside.accent.opacity(item.count > 0 ? 1 : 0))
                            .frame(width: max(item.count > 0 ? 6 : 0, proxy.size.width * item.barRatio))
                    }
                }
                .frame(height: 3)
            }
        }
        .padding(.vertical, 8)
    }

    private func reportBadge(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Bedside.subtext)
                .lineLimit(1)
            Text(value.contains("待累计") ? "—" : value)
                .font(.system(size: 15, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Bedside.text)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WakeTimeLineChart: View {
    let points: [StatsView.WakeTimePoint]

    private var validMinutes: [Int] { points.compactMap(\.minutes) }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                ZStack {
                    if !validMinutes.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(0..<3, id: \.self) { _ in
                            Rectangle()
                                .fill(Bedside.sep)
                                .frame(height: 0.5)
                            Spacer()
                        }
                    }
                    .padding(.vertical, 8)
                    }

                    if validMinutes.isEmpty {
                        Text("完成第一次挑战后，这里会画出你的起床曲线")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Bedside.dim)
                    } else {
                        chartPath(size: proxy.size)
                            .stroke(Bedside.accent, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                        ForEach(Array(points.enumerated()), id: \.element.id) { _, point in
                            if point.minutes != nil {
                                Circle()
                                    .fill(Bedside.accent)
                                    .frame(width: 7, height: 7)
                                    .position(position(for: point, size: proxy.size))
                            }
                        }
                    }
                }
            }

            HStack {
                ForEach(points) { point in
                    Text(point.dayLabel)
                        .font(.system(size: 11, weight: .regular))
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

#Preview { StatsView(sessions: []) }
