import SwiftUI
import AlarmKit

// MARK: - Warm Minimal 色板
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

// 暖炭黑底 + 奶油白字 + 唯一强调色（蜂蜜琥珀）。
// 强调色每屏只给主操作和「开着」的状态用，别拿来刷标题。
enum Bedside {
    static let bg       = Color(hex: "0F0D0B")
    static let surface  = Color(hex: "1A1714")
    static let card     = Color(hex: "1A1714")
    static let raised   = Color(hex: "24201C")
    static let glass    = Color(hex: "24201C").opacity(0.6)
    static let accent   = Color(hex: "E8A25A")
    static let amber    = Color(hex: "E8A25A")
    static let onAccent = Color(hex: "1C1206")
    static let text     = Color(hex: "F2EADF")
    static let subtext  = Color(hex: "A69B8E")
    static let dim      = Color(hex: "6B635A")
    static let sep      = Color(hex: "FFFFFF").opacity(0.07)
    static let green    = Color(hex: "9DBF8C")
    static let red      = Color(hex: "E07B62")
    static let blue     = Color(hex: "8FA9C4")
}

extension Font {
    /// 大号时间、关键数字统一用 New York 衬线细体。
    static func clock(_ size: CGFloat, weight: Font.Weight = .light) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
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
                    Color(hex: "17130F"),
                    Color(hex: "110E0C"),
                    Bedside.bg
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            if glow {
                RadialGradient(
                    colors: [Bedside.accent.opacity(0.07), .clear],
                    center: UnitPoint(x: 0.85, y: 0.0),
                    startRadius: 10,
                    endRadius: 360
                )
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
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Bedside.subtext)
                    .frame(minWidth: 54, alignment: .leading)
            }

            VStack(alignment: leadingTitle == nil ? .leading : .center, spacing: 5) {
                Text(title)
                    .font(.system(size: leadingTitle == nil ? 24 : 17, weight: .semibold))
                    .foregroundStyle(Bedside.text)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular))
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
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(color)
            .frame(width: 32, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(color.opacity(0.12))
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
                    .font(.system(size: 11, weight: .medium))
            }
            Text(text)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(Bedside.subtext)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }
}

// 以前的发光字已退役：只保留着色，避免霓虹感。
struct GlowText: ViewModifier {
    var color: Color = Bedside.amber
    func body(content: Content) -> some View {
        content.foregroundColor(color)
    }
}

extension View {
    func glow(_ color: Color = Bedside.accent) -> some View {
        modifier(GlowText(color: color))
    }
}

/// 平面暖灰卡片：实底 + 一条极细描边，不带光晕和阴影。
struct SurfacePanel: View {
    var radius: CGFloat = 20
    var style: BedsideGlassStyle = .card

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(style == .hero ? Bedside.raised : Bedside.card)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
            )
    }
}

struct DarkCard: ViewModifier {
    var radius: CGFloat = 20
    var style: BedsideGlassStyle = .card

    func body(content: Content) -> some View {
        content.background { SurfacePanel(radius: radius, style: style) }
    }
}

extension View {
    func darkCard(radius: CGFloat = 20, style: BedsideGlassStyle = .card) -> some View {
        modifier(DarkCard(radius: radius, style: style))
    }
}

// 暗色列表组
struct DarkGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .darkCard(radius: 18, style: .card)
    }
}

/// 内容卡片面板：真液态玻璃 + 暖炭色调 + 顶边一道细高光。
/// 不加琥珀光晕、彩色描边和发光阴影，玻璃感靠材质本身。
struct LiquidGlassPanel: View {
    var radius: CGFloat = 20
    var style: BedsideGlassStyle = .card
    var interactive: Bool = false

    private var tint: Color {
        Bedside.raised.opacity(style == .hero ? 0.38 : 0.48)
    }

    var body: some View {
        baseGlass
            .overlay { lightWash }
            .overlay { grain }
            .overlay { topEdgeShine }
            .overlay { bottomEdgeShade }
            .shadow(color: .black.opacity(style == .hero ? 0.35 : 0.25), radius: style == .hero ? 20 : 12, x: 0, y: style == .hero ? 12 : 6)
    }

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

    private var topEdgeShine: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(style == .hero ? 0.16 : 0.11), .white.opacity(0.03), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 0.6
            )
            .allowsHitTesting(false)
    }

    /// 顶光：上沿微亮，往下渐暗，给卡片一点体积。
    private var lightWash: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: Color(hex: "FFE9CF").opacity(style == .hero ? 0.09 : 0.07), location: 0),
                        .init(color: .clear, location: 0.45),
                        .init(color: .black.opacity(0.14), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .allowsHitTesting(false)
    }

    /// 细磨砂颗粒，像磨砂玻璃的手感。
    private var grain: some View {
        BedsideGrain.image
            .resizable(resizingMode: .tile)
            .opacity(0.05)
            .blendMode(.overlay)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .allowsHitTesting(false)
    }

    /// 下沿压一道暗线，做出厚度。
    private var bottomEdgeShade: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [.clear, .clear, .black.opacity(0.35)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
            .allowsHitTesting(false)
    }
}

/// 一次性生成的单色噪点贴图，平铺在卡片上做磨砂颗粒。
enum BedsideGrain {
    static let image: Image = {
        let size = 128
        var pixels = [UInt8](repeating: 0, count: size * size)
        var seed: UInt32 = 0x2F6E_2B1D
        for i in pixels.indices {
            seed = seed &* 1_664_525 &+ 1_013_904_223
            pixels[i] = UInt8(truncatingIfNeeded: seed >> 24)
        }
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        let cgImage = CGImage(
            width: size, height: size,
            bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: size,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )!
        return Image(decorative: cgImage, scale: 2)
    }()
}

/// 悬浮小控件（加号、刷新、稍后提醒等）用的真玻璃胶囊。
struct LiquidGlassCapsule: View {
    var style: BedsideGlassStyle = .card
    var interactive: Bool = false

    var body: some View {
        if interactive {
            Capsule(style: .continuous)
                .fill(.clear)
                .glassEffect(.regular.tint(Bedside.raised.opacity(0.35)).interactive(), in: .rect(cornerRadius: 999))
        } else {
            Capsule(style: .continuous)
                .fill(.clear)
                .glassEffect(.regular.tint(Bedside.raised.opacity(0.35)), in: .rect(cornerRadius: 999))
        }
    }
}

/// 主操作按钮：立体蜂蜜色胶囊，深色字。上浅下深 + 顶部内高光 + 暖色投影。
struct PrimaryCapsuleLabel: View {
    let title: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
            }
            Text(title)
                .font(.system(size: 17, weight: .semibold))
        }
        .foregroundStyle(Bedside.onAccent)
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background { body3D }
    }

    // 第一版的「台灯光柱」：按钮自己发光，和首页台灯呼应。
    private var body3D: some View {
        ZStack {
            // 身后的暖光晕
            Capsule(style: .continuous)
                .fill(Color(hex: "FFB04A").opacity(0.56))
                .blur(radius: 18)
                .offset(y: 8)
            Capsule(style: .continuous)
                .fill(Color(hex: "FFB04A").opacity(0.34))
                .blur(radius: 8)
                .offset(y: -2)

            // 亮金色主体
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "FFD481"), Color(hex: "FFB04A"), Color(hex: "F59A3A")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // 上半截柔光
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.38), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .padding(.horizontal, 2)
                .padding(.top, 1)
                .padding(.bottom, 18)

            // 顶部细高光
            Capsule(style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.5), .white.opacity(0.12)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
        }
        .shadow(color: Color(hex: "FFB04A").opacity(0.46), radius: 22, x: 0, y: 10)
        .shadow(color: Color(hex: "FFB04A").opacity(0.28), radius: 34, x: 0, y: 0)
    }
}

struct AlarmReliabilityCard: View {
    let alarm: Alarm?
    let authorization: AlarmKit.AlarmManager.AuthorizationState
    let scheduledAlarmCount: Int
    let nextScheduledAlarmDate: Date?
    let onRefresh: () -> Void

    // 一切正常时只占一行小字，出问题才展开成卡片。
    private var isHealthy: Bool {
        alarm != nil && authorization.allowsAlarmDelivery && scheduledAlarmCount > 0
    }

    var body: some View {
        if isHealthy {
            compactRow
        } else {
            card
        }
    }

    private var compactRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Bedside.green)
                .frame(width: 6, height: 6)
            Text(detailText)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Bedside.subtext)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Bedside.dim)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("刷新响铃体检")
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("响铃体检正常，\(detailText)")
    }

    private var card: some View {
        HStack(spacing: 14) {
            BedsideIconBadge(systemName: statusIcon, color: statusColor)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text("响铃体检")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Bedside.text)
                    Text(statusText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(statusColor)
                }

                Text(detailText)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Bedside.subtext)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
            }
            Spacer()
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Bedside.subtext)
                    .frame(width: 32, height: 32)
                    .background { LiquidGlassCapsule(style: .card, interactive: true) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("刷新响铃体检")
        }
        .padding(16)
        .background { LiquidGlassPanel(radius: 20, style: .card) }
    }

    private var statusIcon: String {
        if authorization.isBlockingAlarmDelivery { return "bell.slash.fill" }
        if alarm == nil { return "bell.badge.fill" }
        return scheduledAlarmCount > 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
    }

    private var statusColor: Color {
        if authorization.isBlockingAlarmDelivery { return Bedside.red }
        if alarm == nil { return Bedside.amber }
        return scheduledAlarmCount > 0 ? Bedside.green : Bedside.red
    }

    private var statusText: String {
        if authorization.isBlockingAlarmDelivery { return "未通过" }
        if alarm == nil { return "待设置" }
        return scheduledAlarmCount > 0 ? "正常" : "待确认"
    }

    private var detailText: String {
        guard alarm != nil else {
            return "暂无启用闹钟，添加后会交给系统闹钟排班。"
        }
        guard authorization.allowsAlarmDelivery else {
            return "系统闹钟权限未放行，闹钟不会响。"
        }
        guard scheduledAlarmCount > 0 else {
            return "有启用闹钟，但系统闹钟里还没排上。"
        }
        if let nextScheduledAlarmDate {
            return "系统闹钟已排 \(scheduledAlarmCount) 个，下一次 \(AlarmReliabilityDateFormatters.time.string(from: nextScheduledAlarmDate))"
        }
        return "系统闹钟已排 \(scheduledAlarmCount) 个"
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
