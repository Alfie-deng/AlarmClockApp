import SwiftUI

struct AlarmSettingView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var mgr: AlarmManager
    var alarm: Alarm?

    @State private var hour = 7
    @State private var min = 30
    @State private var label = "起床"
    @State private var soundName = "温柔晨光"
    @State private var snoozeMinutes = 5
    @State private var challenge: ChallengeType = .math
    @State private var mathDifficulty: MathDifficulty = .medium
    @State private var mathQuestionCount = 3
    @State private var shakeRequiredCount = 20
    @State private var speechPhrase = "我已经醒了，今天也要准时开始"
    @State private var speechRepeatCount = 1
    @State private var photoTargetLabel = "床头灯"
    @State private var repeatDays: Set<Int> = []
    @State private var requiresChallenge = true
    @State private var showChallengeSettings = false
    @State private var testRecord: ChallengeRecord?
    @State private var soundPlayer = AlarmSoundPlayer()

    var isEdit: Bool { alarm != nil }

    private let weekdayOptions: [(value: Int, label: String)] = [
        (2, "一"),
        (3, "二"),
        (4, "三"),
        (5, "四"),
        (6, "五"),
        (7, "六"),
        (1, "日")
    ]
    private let snoozeOptions = [3, 5, 10, 15]

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
                            ZStack {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white.opacity(0.075))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(Bedside.accent.opacity(0.16), lineWidth: 0.7)
                                    )
                                    .frame(width: 202, height: 34)

                                HStack(spacing: 0) {
                                    Picker("", selection: $hour) {
                                        ForEach(0..<24, id: \.self) { h in
                                            Text(String(format: "%02d", h))
                                                .tag(h)
                                                .foregroundColor(Bedside.text)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .colorScheme(.dark)
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
                                    .colorScheme(.dark)
                                    .frame(width: 116, height: 170)
                                    .clipped()
                                }
                            }
                        }
                        .padding(.top, 4)

                        // 基础设置
                        VStack(spacing: 0) {
                            editableRow(icon: "tag", title: "闹钟名称", text: $label)
                            Divider().background(Bedside.sep).padding(.leading, 56)
                            row(icon: "calendar", color: Bedside.accent, title: "重复") {
                                HStack(spacing: 7) {
                                    ForEach(weekdayOptions, id: \.value) { weekday in
                                        Button {
                                            if repeatDays.contains(weekday.value) { repeatDays.remove(weekday.value) } else { repeatDays.insert(weekday.value) }
                                        } label: {
                                            Text(weekday.label)
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(repeatDays.contains(weekday.value) ? Color.black.opacity(0.78) : Bedside.subtext)
                                                .frame(width: 24, height: 24)
                                                .background(Circle().fill(repeatDays.contains(weekday.value) ? Bedside.accent : Bedside.surface.opacity(0.72)))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            Divider().background(Bedside.sep).padding(.leading, 56)
                            SoundPickerRow(
                                icon: "speaker.wave.2",
                                title: "闹钟声音",
                                selection: $soundName,
                                options: AlarmSound.options.map(\.title),
                                onPreview: { soundPlayer.preview(soundName: soundName) }
                            )
                            Divider().background(Bedside.sep).padding(.leading, 56)
                            row(icon: "moon.zzz.fill", color: Bedside.accent, title: "稍后提醒") {
                                HStack(spacing: 4) {
                                    ForEach(snoozeOptions, id: \.self) { option in
                                        Button {
                                            snoozeMinutes = option
                                        } label: {
                                            Text("\(option)")
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                                .foregroundStyle(snoozeMinutes == option ? Color.black.opacity(0.78) : Bedside.subtext)
                                                .frame(width: option >= 10 ? 28 : 24, height: 24)
                                                .background(
                                                    Capsule(style: .continuous)
                                                        .fill(snoozeMinutes == option ? Bedside.accent : Bedside.surface.opacity(0.72))
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    Text("分")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Bedside.subtext)
                                        .frame(width: 14, alignment: .trailing)
                                        .fixedSize()
                                }
                            }
                            Divider().background(Bedside.sep).padding(.leading, 56)
                            row(icon: "shield.checkered", color: Bedside.accent, title: "起床挑战") {
                                Toggle("", isOn: $requiresChallenge)
                                    .labelsHidden()
                                    .tint(Bedside.accent)
                            }
                        }
                        .alarmSettingPanel(radius: 18)

                        // 挑战设置
                        VStack(spacing: 14) {
                            HStack(spacing: 12) {
                                BedsideIconBadge(systemName: "shield.checkered")
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("挑战方式")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(Bedside.text)
                                    Text(requiresChallenge ? challenge.description : "关闭后闹钟可直接停止")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Bedside.subtext)
                                }
                                Spacer()
                                BedsidePill(text: requiresChallenge ? "已开启" : "已关闭")
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 14)

                            ChallengeModePicker(selection: $challenge, isEnabled: requiresChallenge)
                                .padding(.horizontal, 12)

                            Button { showChallengeSettings = true } label: {
                                HStack(spacing: 12) {
                                    BedsideIconBadge(systemName: "slider.horizontal.3")
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("挑战详情")
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundStyle(Bedside.text)
                                        Text(challengeSummary)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Bedside.subtext)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                    }
                                    Spacer()
                                    Text(challenge.rawValue)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Bedside.amber)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 5)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(Bedside.accent.opacity(0.12))
                                                .overlay(Capsule().stroke(Bedside.accent.opacity(0.18), lineWidth: 0.7))
                                        )
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Bedside.dim)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(!requiresChallenge)
                            .opacity(requiresChallenge ? 1 : 0.45)
                        }
                        .alarmSettingPanel(radius: 18)

                        Button {
                            testRecord = makeTestRecord()
                        } label: {
                            HStack(spacing: 12) {
                                BedsideIconBadge(systemName: "play.circle.fill")
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("测试本次挑战")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundStyle(Bedside.text)
                                    Text("不保存闹钟，只预演响铃和挑战流程")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Bedside.subtext)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Bedside.dim)
                            }
                            .padding(16)
                            .background { LiquidGlassPanel(radius: 18, style: .card, interactive: true) }
                        }
                        .buttonStyle(.plain)

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
                challenge = a.challengeType.isSupported ? a.challengeType : .math
                mathDifficulty = a.mathDifficulty
                mathQuestionCount = a.mathQuestionCount
                shakeRequiredCount = a.shakeRequiredCount
                speechPhrase = a.speechPhrase
                speechRepeatCount = a.speechRepeatCount
                photoTargetLabel = a.photoTargetLabel
                soundName = a.soundName
                snoozeMinutes = a.snoozeMinutes
                repeatDays = a.repeatWeekdays
                requiresChallenge = a.requiresChallenge
            }
        }
        .sheet(isPresented: $showChallengeSettings) {
            ChallengeDetailSettingsView(
                challenge: challenge,
                mathDifficulty: $mathDifficulty,
                mathQuestionCount: $mathQuestionCount,
                shakeRequiredCount: $shakeRequiredCount,
                speechPhrase: $speechPhrase,
                speechRepeatCount: $speechRepeatCount,
                photoTargetLabel: $photoTargetLabel
            )
            .presentationDetents([.medium, .large])
        }
        .fullScreenCover(item: $testRecord) { record in
            RingingView(
                record: record,
                onCorrect: { testRecord = nil },
                onSnooze: { testRecord = nil }
            )
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
            isEnabled: alarm?.isEnabled ?? true,
            requiresChallenge: requiresChallenge,
            challengeType: challenge.isSupported ? challenge : .math,
            mathDifficulty: mathDifficulty,
            label: label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "起床" : label,
            soundName: soundName,
            tag: alarm?.tag ?? "工作日",
            repeatDays: repeatDays,
            snoozeMinutes: snoozeMinutes,
            mathQuestionCount: mathQuestionCount,
            shakeRequiredCount: shakeRequiredCount,
            speechPhrase: speechPhrase,
            speechRepeatCount: speechRepeatCount,
            photoTargetLabel: photoTargetLabel
        )
        if isEdit { mgr.updateAlarm(a) } else { mgr.addAlarm(a) }
    }

    private func makeTestRecord() -> ChallengeRecord {
        let alarm = makeDraftAlarm()
        if !alarm.requiresChallenge {
            return ChallengeRecord(
                alarmId: alarm.id,
                type: .math,
                questions: [MathQuestion(prompt: "点击关闭闹钟", answer: 0)],
                phrase: nil,
                targetPhotoLabel: nil,
                memoryPattern: [],
                difficulty: alarm.mathDifficulty,
                soundName: alarm.soundName,
                shakeRequiredCount: alarm.shakeRequiredCount,
                speechRepeatCount: alarm.speechRepeatCount,
                startedAt: Date(),
                requiresChallenge: false
            )
        }

        switch alarm.challengeType {
        case .math:
            return ChallengeRecord(
                alarmId: alarm.id,
                type: .math,
                questions: makePreviewMathQuestions(difficulty: alarm.mathDifficulty, count: alarm.mathQuestionCount),
                phrase: nil,
                targetPhotoLabel: nil,
                memoryPattern: [],
                difficulty: alarm.mathDifficulty,
                soundName: alarm.soundName,
                shakeRequiredCount: alarm.shakeRequiredCount,
                speechRepeatCount: alarm.speechRepeatCount,
                startedAt: Date()
            )
        case .shake:
            return ChallengeRecord(alarmId: alarm.id, type: .shake, questions: [], phrase: nil, targetPhotoLabel: nil, memoryPattern: [], difficulty: alarm.mathDifficulty, soundName: alarm.soundName, shakeRequiredCount: alarm.shakeRequiredCount, speechRepeatCount: alarm.speechRepeatCount, startedAt: Date())
        case .speak:
            return ChallengeRecord(alarmId: alarm.id, type: .speak, questions: [], phrase: alarm.speechPhrase, targetPhotoLabel: nil, memoryPattern: [], difficulty: alarm.mathDifficulty, soundName: alarm.soundName, shakeRequiredCount: alarm.shakeRequiredCount, speechRepeatCount: alarm.speechRepeatCount, startedAt: Date())
        case .photo:
            return ChallengeRecord(alarmId: alarm.id, type: .photo, questions: [], phrase: nil, targetPhotoLabel: alarm.photoTargetLabel, memoryPattern: [], difficulty: alarm.mathDifficulty, soundName: alarm.soundName, shakeRequiredCount: alarm.shakeRequiredCount, speechRepeatCount: alarm.speechRepeatCount, startedAt: Date())
        case .memory:
            return ChallengeRecord(alarmId: alarm.id, type: .memory, questions: [], phrase: nil, targetPhotoLabel: nil, memoryPattern: Array(0..<4).shuffled(), difficulty: alarm.mathDifficulty, soundName: alarm.soundName, shakeRequiredCount: alarm.shakeRequiredCount, speechRepeatCount: alarm.speechRepeatCount, startedAt: Date())
        }
    }

    private func makeDraftAlarm() -> Alarm {
        var dc = DateComponents(); dc.hour = hour; dc.minute = min
        let time = Calendar.current.date(from: dc) ?? Date()
        return Alarm(
            id: alarm?.id ?? UUID(),
            time: time,
            isEnabled: alarm?.isEnabled ?? true,
            requiresChallenge: requiresChallenge,
            challengeType: challenge.isSupported ? challenge : .math,
            mathDifficulty: mathDifficulty,
            label: label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "起床" : label,
            soundName: soundName,
            tag: alarm?.tag ?? "工作日",
            repeatDays: repeatDays,
            snoozeMinutes: snoozeMinutes,
            mathQuestionCount: mathQuestionCount,
            shakeRequiredCount: shakeRequiredCount,
            speechPhrase: speechPhrase,
            speechRepeatCount: speechRepeatCount,
            photoTargetLabel: photoTargetLabel
        )
    }

    private func makePreviewMathQuestions(difficulty: MathDifficulty, count: Int) -> [MathQuestion] {
        (0..<Alarm.clampedMathQuestionCount(count)).map { _ in
            switch difficulty {
            case .easy:
                let left = Int.random(in: 3...20)
                let right = Int.random(in: 2...18)
                return MathQuestion(prompt: "\(left) + \(right) = ?", answer: left + right)
            case .medium:
                let left = Int.random(in: 10...60)
                let right = Int.random(in: 8...50)
                return MathQuestion(prompt: "\(left) + \(right) = ?", answer: left + right)
            case .hard:
                let left = Int.random(in: 6...16)
                let right = Int.random(in: 4...12)
                let add = Int.random(in: 10...60)
                return MathQuestion(prompt: "\(left) × \(right) + \(add) = ?", answer: left * right + add)
            }
        }
    }

    private var challengeSummary: String {
        switch challenge {
        case .math:
            return "\(mathDifficulty.rawValue) · \(mathQuestionCount) 题"
        case .shake:
            return "摇动 \(shakeRequiredCount) 次"
        case .speak:
            return "念 \(speechRepeatCount) 遍"
        case .photo:
            return "拍到 \(photoTargetLabel)"
        case .memory:
            return "记忆游戏待开放"
        }
    }
}

private struct ChallengeDetailSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let challenge: ChallengeType
    @Binding var mathDifficulty: MathDifficulty
    @Binding var mathQuestionCount: Int
    @Binding var shakeRequiredCount: Int
    @Binding var speechPhrase: String
    @Binding var speechRepeatCount: Int
    @Binding var photoTargetLabel: String

    var body: some View {
        ZStack {
            BedsideAmbientBackground()
            VStack(spacing: 0) {
                BedsideTopBar(
                    title: "挑战详情",
                    leadingTitle: "完成",
                    trailingTitle: "",
                    leadingAction: { dismiss() },
                    trailingAction: {}
                )

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        header
                        detailContent
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationBackground(Bedside.bg)
    }

    private var header: some View {
        HStack(spacing: 12) {
            BedsideIconBadge(systemName: challenge.icon)
            VStack(alignment: .leading, spacing: 4) {
                Text(challenge.rawValue)
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(Bedside.text)
                Text(challenge.description)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Bedside.subtext)
            }
            Spacer()
        }
        .padding(16)
        .alarmSettingPanel(radius: 18)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch challenge {
        case .math:
            VStack(spacing: 0) {
                StepperRow(
                    icon: "number.circle.fill",
                    title: "题目数量",
                    valueText: "\(mathQuestionCount) 题",
                    decrement: { mathQuestionCount = Alarm.clampedMathQuestionCount(mathQuestionCount - 1) },
                    increment: { mathQuestionCount = Alarm.clampedMathQuestionCount(mathQuestionCount + 1) }
                )
                Divider().background(Bedside.sep).padding(.leading, 56)
                VStack(alignment: .leading, spacing: 12) {
                    Text("难度")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Bedside.subtext)
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
            .alarmSettingPanel(radius: 18)
        case .shake:
            VStack(spacing: 0) {
                StepperRow(
                    icon: "iphone.radiowaves.left.and.right",
                    title: "摇动次数",
                    valueText: "\(shakeRequiredCount) 次",
                    decrement: { shakeRequiredCount = Alarm.clampedShakeRequiredCount(shakeRequiredCount - 5) },
                    increment: { shakeRequiredCount = Alarm.clampedShakeRequiredCount(shakeRequiredCount + 5) }
                )
                Text("建议 20–40 次。太少像闹钟放水，太多像手机在参加铁人三项。")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Bedside.subtext)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
            .alarmSettingPanel(radius: 18)
        case .speak:
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("目标语句")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Bedside.subtext)
                    TextField("输入需要念出的语句", text: $speechPhrase, axis: .vertical)
                        .lineLimit(2...4)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Bedside.text)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.black.opacity(0.22))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Bedside.sep, lineWidth: 0.8))
                        )
                }
                .padding(16)
                Divider().background(Bedside.sep).padding(.leading, 56)
                StepperRow(
                    icon: "repeat",
                    title: "念诵次数",
                    valueText: "\(speechRepeatCount) 遍",
                    decrement: { speechRepeatCount = Alarm.clampedSpeechRepeatCount(speechRepeatCount - 1) },
                    increment: { speechRepeatCount = Alarm.clampedSpeechRepeatCount(speechRepeatCount + 1) }
                )
            }
            .alarmSettingPanel(radius: 18)
        case .photo:
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("拍照目标")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Bedside.subtext)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(Alarm.supportedPhotoTargets, id: \.self) { target in
                            Button {
                                photoTargetLabel = target
                            } label: {
                                Text(target)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(photoTargetLabel == target ? Color.black.opacity(0.78) : Bedside.subtext)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 38)
                                    .background(
                                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                                            .fill(photoTargetLabel == target ? Bedside.accent : Color.white.opacity(0.045))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                                    .stroke(photoTargetLabel == target ? Bedside.accent.opacity(0.2) : Bedside.sep.opacity(0.7), lineWidth: 0.7)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text("系统会用本地图像识别判断照片里是否像这个目标。清晨光线太离谱时，它也可能像刚醒的人一样眼神不太好。")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Bedside.subtext)
                        .lineSpacing(3)
                }
                .padding(16)
            }
            .alarmSettingPanel(radius: 18)
        case .memory:
            Text("这个挑战暂未开放。")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Bedside.subtext)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .alarmSettingPanel(radius: 18)
        }
    }
}

private struct StepperRow: View {
    let icon: String
    let title: String
    let valueText: String
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            BedsideIconBadge(systemName: icon)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Bedside.text)
            Spacer()
            Text(valueText)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Bedside.amber)
                .frame(minWidth: 58, alignment: .trailing)
            HStack(spacing: 8) {
                Button(action: decrement) {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 30, height: 30)
                }
                Button(action: increment) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 30, height: 30)
                }
            }
            .foregroundStyle(Bedside.amber)
            .background { LiquidGlassCapsule(style: .card, interactive: true) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

private struct ChallengeModePicker: View {
    @Binding var selection: ChallengeType
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: 10) {
            ForEach(ChallengeType.supportedCases) { type in
                ChallengeModeButton(
                    type: type,
                    isSelected: selection == type,
                    isEnabled: isEnabled,
                    action: { selection = type }
                )
            }
        }
        .opacity(isEnabled ? 1 : 0.45)
    }
}

private struct ChallengeModeButton: View {
    let type: ChallengeType
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(isSelected ? Bedside.accent.opacity(0.22) : Color.white.opacity(0.045))
                        .overlay(Circle().stroke(isSelected ? Bedside.accent.opacity(0.34) : Bedside.sep.opacity(0.7), lineWidth: 0.8))
                        .frame(width: 42, height: 42)

                    Image(systemName: type.icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(isSelected ? Bedside.amber : Bedside.subtext)
                        .frame(width: 42, height: 42)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Bedside.accent)
                            .background(Circle().fill(Color.black.opacity(0.55)))
                            .offset(x: 5, y: -5)
                    }
                }

                Text(type.rawValue)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(isSelected ? Bedside.text : Bedside.subtext)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(shortHint)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(isSelected ? Bedside.amber.opacity(0.92) : Bedside.dim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 112)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Bedside.accent.opacity(0.13) : Color.white.opacity(0.035))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSelected ? Bedside.accent.opacity(0.34) : Bedside.sep.opacity(0.7), lineWidth: isSelected ? 1.1 : 0.7)
                    )
                    .shadow(color: isSelected ? Bedside.accent.opacity(0.16) : .clear, radius: 12, x: 0, y: 5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(type.rawValue)
        .accessibilityValue(isSelected ? "已选择" : "未选择")
    }

    private var shortHint: String {
        switch type {
        case .math:
            return "算清楚再关"
        case .shake:
            return "摇到清醒"
        case .speak:
            return "开口认命"
        case .photo:
            return "拍照验证"
        case .memory:
            return "记住顺序"
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

private struct SoundPickerRow: View {
    let icon: String
    let title: String
    @Binding var selection: String
    let options: [String]
    let onPreview: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            BedsideIconBadge(systemName: icon, color: Bedside.accent)
            Text(title).font(.system(size: 17)).foregroundColor(Bedside.text)
            Spacer()
            Button(action: onPreview) {
                Image(systemName: "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Bedside.amber)
                    .frame(width: 30, height: 28)
                    .background { LiquidGlassCapsule(style: .card, interactive: true) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("试听闹钟声音")

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
