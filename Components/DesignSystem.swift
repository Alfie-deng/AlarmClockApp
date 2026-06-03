import SwiftUI
import UserNotifications

// MARK: - Dark Bedside 色板
extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleaned.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

enum Bedside {
    static let bg       = Color(hex: "05070B")
    static let surface  = Color(hex: "15181E")
    static let card     = Color(hex: "1B1D22").opacity(0.62)
    static let glass    = Color(hex: "202127").opacity(0.48)
    static let accent   = Color(hex: "FFB04A")
    static let amber    = Color(hex: "FFB04A")
    static let text     = Color(hex: "F6EFE5")
    static let subtext  = Color(hex: "B8AAA0")
    static let dim      = Color(hex: "6F737A")
    static let sep      = Color(hex: "FFFFFF").opacity(0.12)
    static let green    = Color(hex: "34C759")
    static let red      = Color(hex: "FF453A")
    static let blue     = Color(hex: "0A84FF")
}

enum BedsideGlassStyle {
    case card
    case hero
}

struct BedsideAmbientBackground: View {
    var glow: Bool = true

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "101824"),
                    Color(hex: "080B10"),
                    Bedside.bg
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            if glow {
                Circle()
                    .fill(Bedside.accent.opacity(0.16))
                    .frame(width: 220, height: 220)
                    .blur(radius: 42)
                    .offset(x: 96, y: -96)

                Circle()
                    .fill(Bedside.amber.opacity(0.08))
                    .frame(width: 260, height: 260)
                    .blur(radius: 56)
                    .offset(x: -92, y: 210)
            }
        }
        .ignoresSafeArea()
    }
}

struct BedsideTopBar: View {
    let title: String
    var subtitle: String? = nil
    var leadingTitle: String? = nil
    var trailingTitle: String? = nil
    var leadingAction: (() -> Void)? = nil
    var trailingAction: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: subtitle == nil ? .center : .top) {
            if let leadingTitle {
                Button(leadingTitle) { leadingAction?() }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Bedside.accent)
                    .frame(minWidth: 54, alignment: .leading)
            }

            VStack(alignment: leadingTitle == nil ? .leading : .center, spacing: 5) {
                Text(title)
                    .font(.system(size: leadingTitle == nil ? 24 : 17, weight: .bold))
                    .foregroundStyle(Bedside.text)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Bedside.subtext)
                }
            }
            .frame(maxWidth: .infinity, alignment: leadingTitle == nil ? .leading : .center)

            if let trailingTitle {
                Button(trailingTitle) { trailingAction?() }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Bedside.accent)
                    .frame(minWidth: 54, alignment: .trailing)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

struct BedsideIconBadge: View {
    let systemName: String
    var color: Color = Bedside.accent

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 34, height: 34)
            .background(
                Circle()
                    .fill(color.opacity(0.14))
                    .overlay(Circle().stroke(.white.opacity(0.08), lineWidth: 0.6))
            )
    }
}

struct BedsidePill: View {
    let text: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
            }
            Text(text)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(Bedside.amber)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(Bedside.accent.opacity(0.13))
                .overlay(Capsule().stroke(Bedside.accent.opacity(0.22), lineWidth: 0.6))
        )
    }
}

// 发光文字修饰
struct GlowText: ViewModifier {
    var color: Color = Bedside.amber
    func body(content: Content) -> some View {
        content
            .foregroundColor(color)
            .shadow(color: color.opacity(0.56), radius: 7, x: 0, y: 0)
            .shadow(color: color.opacity(0.28), radius: 18, x: 0, y: 0)
    }
}

extension View {
    func glow(_ color: Color = Bedside.accent) -> some View {
        modifier(GlowText(color: color))
    }
}

// 暗色玻璃卡片：统一用于首页、闹钟页、统计页、响铃页。
// 止血原则：不再依赖系统 Material / glassEffect，避免暗色场景里白爆。
struct DarkCard: ViewModifier {
    var radius: CGFloat = 18
    var style: BedsideGlassStyle = .card

    private var topOpacity: Double {
        switch style {
        case .card: return 0.82
        case .hero: return 0.76
        }
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "25262B").opacity(topOpacity),
                                Color(hex: "15171C").opacity(topOpacity + 0.04),
                                Color(hex: "08090D").opacity(topOpacity + 0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay { warmGlassBloom }
                    .overlay { glassStroke }
                    .shadow(color: .black.opacity(0.42), radius: 22, x: 0, y: 14)
                    .shadow(color: Bedside.accent.opacity(style == .hero ? 0.16 : 0.08), radius: 18, x: 0, y: 8)
            )
    }

    private var warmGlassBloom: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                RadialGradient(
                    colors: [
                        Bedside.amber.opacity(style == .hero ? 0.18 : 0.10),
                        Bedside.accent.opacity(style == .hero ? 0.07 : 0.04),
                        .clear
                    ],
                    center: UnitPoint(x: 0.88, y: 0.06),
                    startRadius: 6,
                    endRadius: style == .hero ? 210 : 160
                )
            )
            .blendMode(.screen)
    }

    private var glassStroke: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(style == .hero ? 0.28 : 0.20),
                                Bedside.amber.opacity(style == .hero ? 0.25 : 0.16),
                                .white.opacity(0.04),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
            )
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(style == .hero ? 0.14 : 0.09),
                                .white.opacity(0.025),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: UnitPoint(x: 0.76, y: 0.62)
                        )
                    )
                    .blendMode(.screen)
            }
    }
}

extension View {
    func darkCard(radius: CGFloat = 18, style: BedsideGlassStyle = .card) -> some View {
        modifier(DarkCard(radius: radius, style: style))
    }
}

// 暗色列表组
struct DarkGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .darkCard(radius: 16, style: .card)
    }
}

struct DarkGlassPanel: View {
    var radius: CGFloat = 18
    var style: BedsideGlassStyle = .card

    private var topOpacity: Double {
        switch style {
        case .card: return 0.88
        case .hero: return 0.82
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(hex: "25262B").opacity(topOpacity),
                        Color(hex: "15171C").opacity(topOpacity + 0.04),
                        Color(hex: "07080B").opacity(0.96)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                Bedside.amber.opacity(style == .hero ? 0.18 : 0.10),
                                Bedside.accent.opacity(style == .hero ? 0.06 : 0.035),
                                .clear
                            ],
                            center: UnitPoint(x: 0.88, y: 0.06),
                            startRadius: 6,
                            endRadius: style == .hero ? 210 : 150
                        )
                    )
                    .blendMode(.screen)
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(style == .hero ? 0.24 : 0.16),
                                Bedside.amber.opacity(style == .hero ? 0.22 : 0.13),
                                .white.opacity(0.04),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
            }
            .shadow(color: .black.opacity(0.42), radius: 22, x: 0, y: 14)
            .shadow(color: Bedside.accent.opacity(style == .hero ? 0.16 : 0.08), radius: 18, x: 0, y: 8)
    }
}

struct LiquidGlassPanel: View {
    var radius: CGFloat = 18
    var style: BedsideGlassStyle = .card
    var interactive: Bool = false

    private var tint: Color {
        switch style {
        case .card:
            return Color(hex: "1A1716").opacity(0.12)
        case .hero:
            return Color(hex: "1F1812").opacity(0.10)
        }
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            nativeGlass
        } else {
            DarkGlassPanel(radius: radius, style: style)
        }
    }

    @available(iOS 26.0, *)
    private var nativeGlass: some View {
        baseGlass
            .overlay { depthScrim }
            .overlay { highlightStroke }
            .overlay { topEdgeShine }
            .shadow(color: .black.opacity(style == .hero ? 0.42 : 0.32), radius: style == .hero ? 24 : 16, x: 0, y: style == .hero ? 16 : 10)
            .shadow(color: Bedside.amber.opacity(style == .hero ? 0.16 : 0.08), radius: style == .hero ? 20 : 12, x: 0, y: 6)
    }

    @available(iOS 26.0, *)
    @ViewBuilder
    private var baseGlass: some View {
        if interactive {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(.clear)
                .glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: radius))
        } else {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(.clear)
                .glassEffect(.regular.tint(tint), in: .rect(cornerRadius: radius))
        }
    }

    private var depthScrim: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        .white.opacity(style == .hero ? 0.028 : 0.018),
                        Color(hex: "0A0A0D").opacity(style == .hero ? 0.08 : 0.06),
                        .black.opacity(style == .hero ? 0.14 : 0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .blendMode(.softLight)
    }

    private var highlightStroke: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        .white.opacity(style == .hero ? 0.20 : 0.14),
                        Bedside.amber.opacity(style == .hero ? 0.10 : 0.07),
                        .white.opacity(0.035),
                        .black.opacity(0.06)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: style == .hero ? 0.55 : 0.45
            )
            .blendMode(.screen)
    }

    private var topEdgeShine: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        .white.opacity(style == .hero ? 0.12 : 0.08),
                        .white.opacity(0.025),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: UnitPoint(x: 0.68, y: 0.36)
                ),
                lineWidth: style == .hero ? 0.65 : 0.5
            )
            .blendMode(.screen)
            .mask(
                LinearGradient(
                    colors: [.white.opacity(0.72), .white.opacity(0.24), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
}

struct LiquidGlassCapsule: View {
    var style: BedsideGlassStyle = .card
    var interactive: Bool = false

    private var tint: Color {
        switch style {
        case .card:
            return Color(hex: "1A1716").opacity(0.10)
        case .hero:
            return Color(hex: "1F1812").opacity(0.09)
        }
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            nativeGlass
        } else {
            Capsule(style: .continuous)
                .fill(Bedside.glass)
                .overlay(Capsule(style: .continuous).stroke(Bedside.sep, lineWidth: 0.7))
        }
    }

    @available(iOS 26.0, *)
    @ViewBuilder
    private var nativeGlass: some View {
        if interactive {
            Capsule(style: .continuous)
                .fill(.clear)
                .glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: 999))
                .overlay { edgeHighlight }
        } else {
            Capsule(style: .continuous)
                .fill(.clear)
                .glassEffect(.regular.tint(tint), in: .rect(cornerRadius: 999))
                .overlay { edgeHighlight }
        }
    }

    private var edgeHighlight: some View {
        Capsule(style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        .white.opacity(0.28),
                        Bedside.amber.opacity(0.16),
                        .white.opacity(0.05),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.75
            )
            .blendMode(.screen)
    }
}

struct AlarmReliabilityCard: View {
    let alarm: Alarm?
    let notificationStatus: UNAuthorizationStatus
    let pendingNotificationCount: Int
    let nextPendingNotificationDate: Date?
    let onRefresh: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            BedsideIconBadge(systemName: statusIcon, color: statusColor)
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text("响铃体检")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Bedside.text)
                    Text(statusText)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule(style: .continuous)
                                .fill(statusColor.opacity(0.12))
                                .overlay(Capsule().stroke(statusColor.opacity(0.18), lineWidth: 0.6))
                        )
                }

                Text(detailText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Bedside.subtext)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
            }
            Spacer()
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Bedside.amber)
                    .frame(width: 32, height: 32)
                    .background { LiquidGlassCapsule(style: .card, interactive: true) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("刷新响铃体检")
        }
        .padding(16)
        .background { LiquidGlassPanel(radius: 18, style: .card) }
    }

    private var statusIcon: String {
        if notificationStatus.isBlockingAlarmDelivery { return "bell.slash.fill" }
        if alarm == nil { return "bell.badge.fill" }
        return pendingNotificationCount > 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
    }

    private var statusColor: Color {
        if notificationStatus.isBlockingAlarmDelivery { return Bedside.red }
        if alarm == nil { return Bedside.amber }
        return pendingNotificationCount > 0 ? Bedside.green : Bedside.red
    }

    private var statusText: String {
        if notificationStatus.isBlockingAlarmDelivery { return "未通过" }
        if alarm == nil { return "待设置" }
        return pendingNotificationCount > 0 ? "正常" : "待确认"
    }

    private var detailText: String {
        guard alarm != nil else {
            return "暂无启用闹钟，添加后会检查系统通知排班。"
        }
        guard notificationStatus.allowsAlarmDelivery else {
            return "系统通知未放行，闹钟可能不会准时响。"
        }
        guard pendingNotificationCount > 0 else {
            return "有启用闹钟，但暂未检测到待触发通知。"
        }
        if let nextPendingNotificationDate {
            return "已排班 \(pendingNotificationCount) 条，下一次 \(AlarmReliabilityDateFormatters.time.string(from: nextPendingNotificationDate))。"
        }
        return "已排班 \(pendingNotificationCount) 条，等待系统返回下一次时间。"
    }
}

private enum AlarmReliabilityDateFormatters {
    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }()
}

extension UNAuthorizationStatus {
    var isBlockingAlarmDelivery: Bool {
        switch self {
        case .denied, .ephemeral:
            return true
        default:
            return false
        }
    }

    var allowsAlarmDelivery: Bool {
        switch self {
        case .authorized, .provisional:
            return true
        default:
            return false
        }
    }
}
