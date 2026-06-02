import SwiftUI

struct AlarmSettingView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var mgr: AlarmManager
    var alarm: Alarm?
    
    @State private var hour = 7
    @State private var min = 30
    @State private var label = "起床"
    @State private var soundName = "温柔晨光"
    @State private var tag = "工作日"
    @State private var challenge: ChallengeType = .math
    @State private var mathDifficulty: MathDifficulty = .medium
    @State private var repeatDays: Set<Int> = []
    @State private var wakeChallengeEnabled = true
    
    var isEdit: Bool { alarm != nil }
    
    var body: some View {
        ZStack {
            BedsideAmbientBackground()
            VStack(spacing: 0) {
                BedsideTopBar(
                    title: isEdit ? "编辑闹钟" : "添加闹钟",
                    leadingTitle: "取消",
                    trailingTitle: "保存",
                    leadingAction: { dismiss() },
                    trailingAction: { save(); dismiss() }
                )
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        VStack(spacing: 10) {
                            Text("选择时间")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Bedside.subtext)
                                .tracking(1.4)
                            
                            HStack(spacing: 0) {
                                Picker("", selection: $hour) {
                                    ForEach(0..<24, id: \.self) { h in
                                        Text(String(format: "%02d", h))
                                            .tag(h)
                                            .foregroundColor(Bedside.text)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 116, height: 170)
                                .clipped()
                                
                                Text(":")
                                    .font(.system(size: 34, weight: .light, design: .rounded))
                                    .foregroundColor(Bedside.accent)
                                    .offset(y: -2)
                                
                                Picker("", selection: $min) {
                                    ForEach(0..<60, id: \.self) { m in
                                        Text(String(format: "%02d", m))
                                            .tag(m)
                                            .foregroundColor(Bedside.text)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 116, height: 170)
                                .clipped()
                            }
                            
                            Text("AM")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Bedside.amber.opacity(0.78))
                        }
                        .padding(.top, 4)
                        
                        // 标签 & 重复
                        VStack(spacing: 0) {
                            editableRow(icon: "tag", title: "闹钟名称", text: $label)
                            Divider().background(Bedside.sep).padding(.leading, 56)
                            row(icon: "calendar", color: Bedside.accent, title: "重复") {
                                HStack(spacing: 7) {
                                    ForEach(Array(["一", "二", "三", "四", "五", "六", "日"].enumerated()), id: \.offset) { index, day in
                                        Button {
                                            if repeatDays.contains(index) { repeatDays.remove(index) } else { repeatDays.insert(index) }
                                        } label: {
                                            Text(day)
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(repeatDays.contains(index) ? Color.black.opacity(0.78) : Bedside.subtext)
                                                .frame(width: 24, height: 24)
                                                .background(Circle().fill(repeatDays.contains(index) ? Bedside.accent : Bedside.surface.opacity(0.72)))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            Divider().background(Bedside.sep).padding(.leading, 56)
                            PickerRow(icon: "speaker.wave.2", title: "闹钟声音", selection: $soundName, options: ["温柔晨光", "森林鸟鸣", "海边微风"])
                            Divider().background(Bedside.sep).padding(.leading, 56)
                            PickerRow(icon: "tag.fill", title: "标签", selection: $tag, options: ["工作日", "周末", "运动", "学习"])
                            Divider().background(Bedside.sep).padding(.leading, 56)
                            row(icon: "shield.checkered", color: Bedside.accent, title: "起床挑战") {
                                Toggle("", isOn: $wakeChallengeEnabled)
                                    .labelsHidden()
                                    .tint(Bedside.accent)
                            }
                        }
                        .alarmSettingPanel(radius: 18)
                        
                        // 挑战设置
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                BedsideIconBadge(systemName: "shield.checkered")
                                Text("挑战方式").font(.system(size: 17)).foregroundColor(Bedside.text)
                                Spacer()
                                BedsidePill(text: wakeChallengeEnabled ? "已开启" : "已关闭")
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            
                            Divider().background(Bedside.sep).padding(.leading, 56)
                            
                            ForEach(ChallengeType.allCases) { type in
                                Button { challenge = type } label: {
                                    HStack {
                                        Image(systemName: type.icon).font(.system(size: 18))
                                            .foregroundColor(challenge == type ? Bedside.accent : Bedside.dim).frame(width: 28)
                                        Text(type.rawValue).font(.system(size: 16)).foregroundColor(Bedside.text)
                                        Spacer()
                                        if challenge == type {
                                            Image(systemName: "checkmark.circle.fill").font(.system(size: 18)).foregroundColor(Bedside.accent)
                                        }
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 10)
                                    .background(challenge == type ? Bedside.accent.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                            
                            if challenge == .math {
                                Divider().background(Bedside.sep).padding(.leading, 56)
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("数学题预览")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Bedside.subtext)
                                    Text(mathPreview)
                                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Bedside.amber)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                    Picker("难度", selection: $mathDifficulty) {
                                        ForEach(MathDifficulty.allCases) { difficulty in
                                            Text(difficulty.rawValue).tag(difficulty)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .tint(Bedside.accent)
                                }
                                .padding(16)
                            }
                        }
                        .alarmSettingPanel(radius: 18)
                        
                        if isEdit {
                            Button {
                                if let a = alarm { mgr.deleteAlarm(a) }
                                dismiss()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash").font(.system(size: 14))
                                    Text("删除闹钟").font(.system(size: 16, weight: .medium))
                                }.foregroundColor(Bedside.red)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .alarmSettingPanel(radius: 16)
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20).padding(.bottom, 32)
                }
            }
        }
        .onAppear {
            if let a = alarm {
                let c = Calendar.current.dateComponents([.hour, .minute], from: a.time)
                hour = c.hour ?? 7
                min = c.minute ?? 30
                label = a.label
                challenge = a.challengeType
                mathDifficulty = a.mathDifficulty
                soundName = a.soundName
                tag = a.tag
                repeatDays = a.repeatDays
                wakeChallengeEnabled = a.isEnabled
            }
        }
        .preferredColorScheme(.dark)
        .presentationBackground(Bedside.bg)
    }
    
    private func row<Content: View>(icon: String, color: Color, title: String, @ViewBuilder trailing: () -> Content) -> some View {
        HStack(spacing: 12) {
            BedsideIconBadge(systemName: icon, color: color)
            Text(title).font(.system(size: 17)).foregroundColor(Bedside.text)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
    
    private func editableRow(icon: String, title: String, text: Binding<String>) -> some View {
        row(icon: icon, color: Bedside.accent, title: title) {
            TextField(title, text: text)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 16))
                .foregroundStyle(Bedside.text)
        }
    }
    
    private func save() {
        var dc = DateComponents(); dc.hour = hour; dc.minute = min
        let time = Calendar.current.date(from: dc) ?? Date()
        let a = Alarm(
            id: alarm?.id ?? UUID(),
            time: time,
            isEnabled: wakeChallengeEnabled,
            challengeType: challenge,
            mathDifficulty: mathDifficulty,
            label: label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "起床" : label,
            soundName: soundName,
            tag: tag,
            repeatDays: repeatDays,
            snoozeMinutes: 5
        )
        if isEdit { mgr.updateAlarm(a) } else { mgr.addAlarm(a) }
    }
    
    private var mathPreview: String {
        switch mathDifficulty {
        case .easy: return "8 + 15 = ?"
        case .medium: return "27 + 36 = ?"
        case .hard: return "12 × 8 + 35 = ?"
        }
    }
}

private struct PickerRow: View {
    let icon: String
    let title: String
    @Binding var selection: String
    let options: [String]
    
    var body: some View {
        HStack(spacing: 12) {
            BedsideIconBadge(systemName: icon, color: Bedside.accent)
            Text(title).font(.system(size: 17)).foregroundColor(Bedside.text)
            Spacer()
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option) { selection = option }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(selection)
                        .font(.system(size: 16))
                        .foregroundStyle(Bedside.subtext)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Bedside.dim)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}

private extension View {
    func alarmSettingPanel(radius: CGFloat) -> some View {
        background { LiquidGlassPanel(radius: radius, style: .card) }
    }
}

#Preview { AlarmSettingView().environmentObject(AlarmManager()) }
