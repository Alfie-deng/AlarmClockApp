import SwiftUI

struct StatsView: View {
    @EnvironmentObject var mgr: AlarmManager
    
    private enum WeekDayState {
        case completed(WakeSession)
        case missed
        case pending
        
        var isCompleted: Bool {
            if case .completed = self { return true }
            return false
        }
        
        var isCounted: Bool {
            switch self {
            case .completed, .missed: return true
            case .pending: return false
            }
        }
    }
    
    private struct WeekWakeItem: Identifiable {
        let id = UUID()
        let weekday: String
        let detail: String
        let state: WeekDayState
    }
    
    private var completedSessions: [WakeSession] {
        WakeSessionStats.completedSessions(mgr.wakeSessions)
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
                    Text("本周完成")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Bedside.subtext)
                    Text("\(weekSuccessCount)/\(elapsedWeekDayCount)")
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(Bedside.text)
                    Text(weekRemainingText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Bedside.dim)
                }
            }
            
            HStack(spacing: 10) {
                statMetric(title: "平均用时", value: averageDurationText)
                statMetric(title: "最长连续", value: "\(bestStreak)天")
                statMetric(title: "最快完成", value: fastestDurationText)
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
                BedsidePill(text: "\(weekSuccessCount)/\(elapsedWeekDayCount) 已完成", icon: "checkmark.circle")
            }
            
            HStack(spacing: 8) {
                ForEach(weekItems) { item in
                    VStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(dayFill(for: item.state))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(dayStroke(for: item.state), lineWidth: 0.7)
                                )
                            
                            Image(systemName: dayIcon(for: item.state))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(dayIconColor(for: item.state))
                        }
                        .frame(height: 38)
                        
                        Text(item.weekday)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Bedside.subtext)
                        
                        Text(item.detail)
                            .font(.system(size: 9, weight: .medium))
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                            .foregroundColor(dayDetailColor(for: item.state))
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
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.78)
                .lineLimit(1)
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
        weekItems.filter { $0.state.isCompleted }.count
    }
    
    private var elapsedWeekDayCount: Int {
        max(1, weekItems.filter { $0.state.isCounted }.count)
    }
    
    private var weekRemainingText: String {
        let remaining = max(0, 7 - elapsedWeekDayCount)
        let missed = max(0, elapsedWeekDayCount - weekSuccessCount)
        if remaining > 0 {
            return missed > 0 ? "已错过 \(missed) 天 · 剩余 \(remaining) 天" : "剩余 \(remaining) 天"
        }
        return missed > 0 ? "本周错过 \(missed) 天" : "本周全勤"
    }
    
    private var weekItems: [WeekWakeItem] {
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
                return WeekWakeItem(weekday: symbols[weekdayIndex], detail: shortTime(session.completedAt), state: .completed(session))
            }
            if day > today {
                return WeekWakeItem(weekday: symbols[weekdayIndex], detail: "待开始", state: .pending)
            }
            let detail = calendar.isDate(day, inSameDayAs: today) ? "待完成" : "未完成"
            return WeekWakeItem(weekday: symbols[weekdayIndex], detail: detail, state: .missed)
        }
    }
    
    private var currentStreak: Int {
        WakeSessionStats.currentStreak(sessions: completedSessions, endingOn: Date())
    }
    
    private var bestStreak: Int {
        WakeSessionStats.bestStreak(sessions: completedSessions)
    }
    
    private var averageDurationText: String {
        guard !completedSessions.isEmpty else { return "暂无" }
        let avg = completedSessions.map(\.durationSeconds).reduce(0, +) / completedSessions.count
        return durationText(avg)
    }
    
    private var fastestDurationText: String {
        guard let fastest = completedSessions.map(\.durationSeconds).min() else { return "暂无" }
        return durationText(fastest)
    }
    
    private var insights: [(String, String, String)] {
        if completedSessions.isEmpty {
            return [
                ("lightbulb.fill", "等待首次记录", "完成一次挑战后生成真实洞察"),
                ("chart.line.uptrend.xyaxis", "进步趋势", "连续记录越多，趋势越准"),
                ("calendar", "本周状态", "今天完成后会点亮本周记录")
            ]
        }
        let missed = max(0, elapsedWeekDayCount - weekSuccessCount)
        return [
            ("lightbulb.fill", "早晨效率", "平均完成用时 \(averageDurationText)"),
            ("chart.line.uptrend.xyaxis", "连续趋势", currentStreak > 0 ? "当前连续 \(currentStreak) 天" : "今天还没完成，连续待续"),
            ("calendar", "本周状态", missed == 0 ? "已发生日期全部完成" : "本周已错过 \(missed) 天")
        ]
    }
    
    private func shortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func durationText(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        if minutes > 0 { return "\(minutes)分\(seconds)秒" }
        return "\(seconds)秒"
    }
    
    private func dayFill(for state: WeekDayState) -> Color {
        switch state {
        case .completed: return Bedside.accent.opacity(0.16)
        case .missed: return Bedside.red.opacity(0.10)
        case .pending: return Bedside.dim.opacity(0.08)
        }
    }
    
    private func dayStroke(for state: WeekDayState) -> Color {
        switch state {
        case .completed: return Bedside.accent.opacity(0.28)
        case .missed: return Bedside.red.opacity(0.20)
        case .pending: return Bedside.sep
        }
    }
    
    private func dayIcon(for state: WeekDayState) -> String {
        switch state {
        case .completed: return "checkmark"
        case .missed: return "xmark"
        case .pending: return "clock"
        }
    }
    
    private func dayIconColor(for state: WeekDayState) -> Color {
        switch state {
        case .completed: return Bedside.accent
        case .missed: return Bedside.red.opacity(0.74)
        case .pending: return Bedside.dim
        }
    }
    
    private func dayDetailColor(for state: WeekDayState) -> Color {
        switch state {
        case .completed: return Bedside.dim
        case .missed: return Bedside.red.opacity(0.72)
        case .pending: return Bedside.dim.opacity(0.78)
        }
    }
}

#Preview { StatsView().environmentObject(AlarmManager()) }
