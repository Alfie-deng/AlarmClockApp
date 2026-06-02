import SwiftUI

struct StatsView: View {
    @EnvironmentObject var mgr: AlarmManager
    
    private var completedSessions: [WakeSession] {
        mgr.wakeSessions.filter { !$0.emergencyClosed }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                BedsideAmbientBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        BedsideTopBar(title: "统计", subtitle: "记录你的起床节奏")
                            .padding(.horizontal, -20)
                        
                        statsHero
                        weeklyWakeStatus
                        insightsSection
                    }
                    .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 100)
                }
            }
        }
    }
    
    private var statsHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("当前连续")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Bedside.subtext)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(currentStreak)")
                            .font(.system(size: 72, weight: .light, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Bedside.amber)
                            .shadow(color: Bedside.accent.opacity(0.28), radius: 12)
                        Text("天")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Bedside.subtext)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    Text("本周成功")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Bedside.subtext)
                    Text("\(weekSuccessCount)/7")
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(Bedside.text)
                    Text("\(max(0, 7 - weekSuccessCount)) 天未完成")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Bedside.dim)
                }
            }
            
            HStack(spacing: 10) {
                statMetric(title: "平均用时", value: averageDurationText)
                statMetric(title: "最长连续", value: "\(bestStreak)天")
                statMetric(title: "最快反应", value: fastestDurationText)
            }
        }
        .padding(22)
        .background { LiquidGlassPanel(radius: 22, style: .hero) }
    }
    
    private var weeklyWakeStatus: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("本周起床")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Bedside.text)
                Spacer()
                BedsidePill(text: "\(weekSuccessCount) 天完成", icon: "checkmark.circle")
            }
            
            HStack(spacing: 8) {
                ForEach(Array(weekItems.enumerated()), id: \.offset) { _, item in
                    VStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(item.2 ? Bedside.accent.opacity(0.16) : Bedside.dim.opacity(0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(item.2 ? Bedside.accent.opacity(0.28) : Bedside.sep, lineWidth: 0.7)
                                )
                            
                            Image(systemName: item.2 ? "checkmark" : "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(item.2 ? Bedside.accent : Bedside.dim)
                        }
                        .frame(height: 38)
                        
                        Text(item.0)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Bedside.subtext)
                        
                        Text(item.1)
                            .font(.system(size: 9, weight: .medium))
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                            .foregroundColor(item.2 ? Bedside.dim : Bedside.red.opacity(0.72))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(18)
        .background { LiquidGlassPanel(radius: 18, style: .card) }
    }
    
    private func statMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Bedside.dim)
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(Bedside.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("洞察").font(.system(size: 14, weight: .semibold)).foregroundColor(Bedside.subtext)
            VStack(spacing: 0) {
                ForEach(Array(insights.enumerated()), id: \.offset) { i, item in
                    HStack(spacing: 12) {
                        Image(systemName: item.0).font(.system(size: 16)).foregroundColor(Bedside.accent).frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.1).font(.system(size: 14, weight: .semibold)).foregroundColor(Bedside.text)
                            Text(item.2).font(.system(size: 12)).foregroundColor(Bedside.subtext)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    if i < insights.count - 1 { Divider().background(Bedside.sep).padding(.leading, 52) }
                }
            }
            .background { LiquidGlassPanel(radius: 14, style: .card) }
        }
    }
    
    private var weekSuccessCount: Int {
        weekItems.filter(\.2).count
    }
    
    private var weekItems: [(String, String, Bool)] {
        let calendar = Calendar.current
        let symbols = ["日", "一", "二", "三", "四", "五", "六"]
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let startOffset = 2 - weekday
        let monday = calendar.date(byAdding: .day, value: startOffset, to: today) ?? today
        
        return (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: monday) ?? today
            let weekdayIndex = calendar.component(.weekday, from: day) - 1
            let session = completedSessions.first { calendar.isDate($0.completedAt, inSameDayAs: day) }
            if let session {
                return (symbols[weekdayIndex], shortTime(session.completedAt), true)
            }
            return (symbols[weekdayIndex], "未完成", false)
        }
    }
    
    private var currentStreak: Int {
        streakEnding(on: Date())
    }
    
    private var bestStreak: Int {
        let days = Set(completedSessions.map(\.completedDay)).sorted()
        guard !days.isEmpty else { return 0 }
        var best = 1
        var current = 1
        for index in days.indices.dropFirst() {
            let previous = days[days.index(before: index)]
            let day = days[index]
            if Calendar.current.dateComponents([.day], from: previous, to: day).day == 1 {
                current += 1
            } else {
                current = 1
            }
            best = max(best, current)
        }
        return best
    }
    
    private func streakEnding(on date: Date) -> Int {
        let calendar = Calendar.current
        let days = Set(completedSessions.map(\.completedDay))
        var count = 0
        var cursor = calendar.startOfDay(for: date)
        while days.contains(cursor) {
            count += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return count
    }
    
    private var averageDurationText: String {
        guard !completedSessions.isEmpty else { return "暂无" }
        let avg = completedSessions.map(\.durationSeconds).reduce(0, +) / completedSessions.count
        return "\(avg)秒"
    }
    
    private var fastestDurationText: String {
        guard let fastest = completedSessions.map(\.durationSeconds).min() else { return "暂无" }
        return "\(fastest)秒"
    }
    
    private var insights: [(String, String, String)] {
        if completedSessions.isEmpty {
            return [
                ("lightbulb.fill", "等待首次记录", "完成一次挑战后生成真实洞察"),
                ("chart.line.uptrend.xyaxis", "进步趋势", "连续记录越多，趋势越准"),
                ("calendar", "即将解锁", "先完成今天的起床挑战")
            ]
        }
        return [
            ("lightbulb.fill", "早晨效率", "平均完成用时 \(averageDurationText)"),
            ("chart.line.uptrend.xyaxis", "进步趋势", "当前连续 \(currentStreak) 天"),
            ("calendar", "即将解锁", "历史最长 \(bestStreak) 天")
        ]
    }
    
    private func shortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

#Preview { StatsView().environmentObject(AlarmManager()) }
