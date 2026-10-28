import SwiftUI

private enum RingingDateFormatters {
    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}


struct RingingIntroView: View {
    let timeText: String
    let challengeName: String
    let onStartChallenge: () -> Void
    let onSnooze: () -> Void

    var body: some View {
        ZStack {
            RingingAmbientBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                Text("起床闹钟")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(Bedside.text)

                Text(timeText)
                    .font(.system(size: 96, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .glow(Bedside.amber)
                    .padding(.top, 20)

                BedsidePill(text: "挑战模式：\(challengeName)", icon: "shield.checkered")
                    .padding(.top, 10)

                Spacer()

                VStack(spacing: 18) {
                    BedsideIconBadge(systemName: "alarm.waves.left.and.right.fill")
                        .scaleEffect(1.3)

                    VStack(spacing: 8) {
                        Text("完成挑战才能关闭闹钟")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Bedside.text)
                        Text("开始挑战，让大脑先开机")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Bedside.subtext)
                    }
                    .multilineTextAlignment(.center)

                    Button(action: onStartChallenge) {
                        HStack(spacing: 10) {
                            Text("开始挑战")
                                .font(.system(size: 17, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(Color.black.opacity(0.82))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule(style: .continuous)
                                .fill(LinearGradient(colors: [Bedside.amber, Bedside.accent], startPoint: .topLeading, endPoint: .bottomTrailing))
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(24)
                .ringingPanel(radius: 24)
                .padding(.horizontal, 24)

                Spacer()

                Button(action: onSnooze) {
                    HStack(spacing: 6) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 13))
                        Text("稍后提醒")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(Bedside.dim)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background { LiquidGlassCapsule(style: .card, interactive: true) }
                }
                .buttonStyle(.plain)
                .padding(.bottom, 40)
            }
        }
    }
}

struct RingingView: View {
    let record: ChallengeRecord
    let isTestMode: Bool
    let onCorrect: () -> Void
    let onEmergencyClose: () -> Void

    @State private var answer = ""
    @State private var result: Bool? = nil
    @State private var questionIndex = 0
    @State private var memoryInput: [Int] = []
    @State private var speechCompletedCount = 0
    @State private var photoCompletionScheduled = false
    @State private var photoCompletionGeneration = UUID()
    @State private var soundPlayer = AlarmSoundPlayer()
    @StateObject private var shakeController: ShakeChallengeController
    @StateObject private var speechController = SpeechChallengeController()
    @StateObject private var cameraController = CameraChallengeController()

    init(record: ChallengeRecord, isTestMode: Bool = false, onCorrect: @escaping () -> Void, onEmergencyClose: @escaping () -> Void) {
        self.record = record
        self.isTestMode = isTestMode
        self.onCorrect = onCorrect
        self.onEmergencyClose = onEmergencyClose
        let requiredCount = ProcessInfo.processInfo.arguments.contains("--debugShakeRequiredCount") ? Self.debugShakeRequiredCount : record.shakeRequiredCount
        _shakeController = StateObject(wrappedValue: ShakeChallengeController(requiredCount: requiredCount))
    }

    private static var debugShakeRequiredCount: Int {
        guard let index = ProcessInfo.processInfo.arguments.firstIndex(of: "--debugShakeRequiredCount"),
              ProcessInfo.processInfo.arguments.indices.contains(index + 1),
              let count = Int(ProcessInfo.processInfo.arguments[index + 1]) else {
            return 20
        }
        return max(1, count)
    }

    private static var debugSpeechNoAutoStart: Bool {
        ProcessInfo.processInfo.arguments.contains("--debugSpeechNoAutoStart")
    }

    var body: some View {
        ZStack {
            RingingAmbientBackground()
                .ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer(minLength: 16)

                // 发光时间
                Text("起床闹钟")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Bedside.text)
                    .padding(.bottom, 20)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(RingingDateFormatters.time.string(from: context.date))
                        .font(.system(size: 82, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .glow(Bedside.amber)
                }
                if shouldShowExternalChallengePill {
                    BedsidePill(text: "挑战模式：\(record.type.rawValue)", icon: "shield.checkered")
                        .padding(.top, 10)
                }

                Spacer()

                // 挑战卡片
                challengeContent

                Spacer()

                // 紧急关闭
                Button { onEmergencyClose() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isTestMode ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 13))
                        Text(isTestMode ? "退出测试" : "紧急关闭（计入失败）")
                            .font(.system(size: 14, weight: isTestMode ? .semibold : .medium))
                    }
                    .foregroundColor(isTestMode ? Bedside.subtext : Bedside.dim)
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background { LiquidGlassCapsule(style: .card, interactive: true) }
                }
                .buttonStyle(.plain)
                .padding(.bottom, 40)
            }
            .safeAreaPadding(.top, 18)
        }
        .onAppear {
            soundPlayer.start(soundName: record.soundName)
        }
        .onDisappear {
            soundPlayer.stop()
            cameraController.cancelPendingAnalysis()
            photoCompletionGeneration = UUID()
        }
    }

    private var shouldShowExternalChallengePill: Bool {
        ![ChallengeType.math, .shake, .photo].contains(record.type)
    }

    @ViewBuilder
    private var challengeContent: some View {
        if !record.requiresChallenge {
            dismissOnlyCard
        } else {
            switch record.type {
            case .math: mathCard
            case .shake: shakeCard
            case .speak: speakCard
            case .photo: photoCard
            case .memory: unavailableCard
            }
        }
    }

    private var dismissOnlyCard: some View {
        VStack(spacing: 22) {
            BedsideIconBadge(systemName: "alarm.fill")
                .scaleEffect(1.18)
            VStack(spacing: 8) {
                Text("闹钟响了")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Bedside.text)
                Text("当前闹钟未启用起床挑战，可以直接关闭。")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Bedside.subtext)
                    .multilineTextAlignment(.center)
            }
            Button("关闭闹钟") { onCorrect() }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.82))
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(Capsule(style: .continuous).fill(Bedside.accent))
        }
        .padding(42)
        .ringingPanel(radius: 24)
        .padding(.horizontal, 24)
    }

    private var unavailableCard: some View {
        VStack(spacing: 20) {
            Image(systemName: record.type.icon)
                .font(.system(size: 48))
                .foregroundStyle(Bedside.accent)
            VStack(spacing: 8) {
                Text("\(record.type.rawValue)挑战暂未开放")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Bedside.text)
                Text("当前正式可用的是数学题、摇手机和拍照挑战。这个模式还需要接入真实能力后再开放。")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Bedside.subtext)
                    .multilineTextAlignment(.center)
            }
            Button("先关闭闹钟") { onCorrect() }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.82))
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(Capsule(style: .continuous).fill(Bedside.accent))
        }
        .padding(42)
        .ringingPanel(radius: 24)
        .padding(.horizontal, 24)
    }

    // MARK: - 数学挑战
    private var mathCard: some View {
        VStack(spacing: 18) {
            HStack {
                Spacer()
                challengeModePill("数学题")
                Spacer()
            }

            VStack(spacing: 18) {
                Text(currentQuestion?.prompt ?? record.question)
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.44)
                    .foregroundColor(Bedside.text)
                    .shadow(color: Bedside.amber.opacity(0.18), radius: 10)

                answerField
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)

            VStack(spacing: 12) {
                ForEach(0..<3) { row in
                    HStack(spacing: 14) {
                        ForEach(1...3, id: \.self) { col in
                            keyBtn("\(row * 3 + col)") { answer.append("\(row * 3 + col)") }
                        }
                    }
                }
                HStack(spacing: 14) {
                    keyBtn(icon: "delete.left") { if !answer.isEmpty { answer.removeLast() } }
                    keyBtn("0") { answer.append("0") }
                    keyBtn(icon: "checkmark") { checkAnswer() }.disabled(answer.isEmpty)
                }
            }
            .padding(.top, 2)
            .padding(.bottom, 6)

            if let r = result {
                HStack(spacing: 6) {
                    Image(systemName: r ? "checkmark.circle.fill" : "xmark.circle.fill")
                    Text(r ? "正确！" : "再试一次")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(r ? Bedside.green : Bedside.red)
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(Capsule().fill((r ? Bedside.green : Bedside.red).opacity(0.12)))
                .transition(.scale.combined(with: .opacity).animation(.spring()))
            }
        }
        .padding(20)
        .ringingPanel(radius: 24)
        .padding(.horizontal, 24)
    }

    private func challengeModePill(_ title: String) -> some View {
        Label("挑战模式：\(title)", systemImage: "shield.checkered")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Bedside.amber)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(Bedside.accent.opacity(0.14))
                    .overlay(Capsule().stroke(Bedside.accent.opacity(0.24), lineWidth: 0.7))
            )
    }

    private func keyBtn(_ title: String? = nil, icon: String? = nil, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        let isConfirm = icon == "checkmark"

        return Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isConfirm
                                ? [Bedside.accent.opacity(disabled ? 0.16 : 0.72), Bedside.amber.opacity(disabled ? 0.10 : 0.42)]
                                : [Color.white.opacity(disabled ? 0.035 : 0.09), Color.white.opacity(disabled ? 0.02 : 0.045)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                isConfirm
                                    ? Bedside.accent.opacity(disabled ? 0.12 : 0.32)
                                    : Color.white.opacity(disabled ? 0.06 : 0.13),
                                lineWidth: 0.8
                            )
                    )
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.18))
                            .blur(radius: 7)
                            .offset(y: 5)
                    )
                    .shadow(color: isConfirm ? Bedside.accent.opacity(disabled ? 0.04 : 0.18) : .black.opacity(0.18), radius: 10, x: 0, y: 5)
                    .opacity(disabled ? 0.52 : 1)

                if let t = title {
                    Text(t)
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(disabled ? Bedside.dim : Bedside.text)
                } else if let i = icon {
                    Image(systemName: i)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(i == "checkmark" ? Bedside.text.opacity(disabled ? 0.38 : 0.92) : Bedside.subtext)
                }
            }
            .frame(width: 80, height: 80)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var answerField: some View {
        HStack(spacing: 10) {
            Text(answer.isEmpty ? "输入答案" : answer)
                .font(.system(size: answer.isEmpty ? 18 : 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(answer.isEmpty ? Bedside.dim : Bedside.amber)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .frame(maxWidth: .infinity, minHeight: 56)

            if !answer.isEmpty {
                Text("\(answer.count) 位")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Bedside.subtext)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Bedside.surface.opacity(0.72), in: Capsule(style: .continuous))
            }
        }
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(answer.isEmpty ? Bedside.sep : Bedside.accent.opacity(0.36), lineWidth: 0.8)
                )
        )
    }

    // MARK: - 摇晃挑战
    private var shakeCard: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                challengeModePill("摇手机")
                Spacer()
            }

            VStack(spacing: 6) {
                Text("\(shakeController.count)/\(shakeController.requiredCount)")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Bedside.text)
                    .shadow(color: Bedside.amber.opacity(0.18), radius: 10)

                Text(shakeController.isMotionAvailable ? "用力摇晃手机" : "模拟器不支持传感器")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Bedside.subtext)
            }

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.26))
                    .frame(height: 18)
                    .overlay(Capsule().stroke(Bedside.sep, lineWidth: 0.7))

                Capsule(style: .continuous)
                    .fill(LinearGradient(colors: [Bedside.amber, Bedside.accent], startPoint: .leading, endPoint: .trailing))
                    .frame(maxWidth: .infinity)
                    .frame(width: max(18, CGFloat(shakeController.progress) * 260), height: 18)
                    .shadow(color: Bedside.accent.opacity(0.28), radius: 10)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 7) {
                Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(Bedside.accent)
                    .symbolEffect(.pulse, options: .repeating, value: shakeController.count)
                Text(shakeController.isRunning ? "传感器监听中" : "准备开始")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Bedside.subtext)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)

            if !shakeController.isMotionAvailable {
                Button {
                    shakeController.recordMockShake()
                } label: {
                    Label("模拟摇动一次", systemImage: "hand.raised.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Bedside.amber)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background { LiquidGlassCapsule(style: .card, interactive: true) }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .ringingPanel(radius: 24)
        .padding(.horizontal, 24)
        .onAppear {
            shakeController.start(onComplete: onCorrect)
        }
        .onDisappear {
            shakeController.stop()
        }
    }

    // MARK: - 语音挑战
    private var speakCard: some View {
        let phrase = record.phrase ?? "我已经醒了，今天也要准时开始"
        return VStack(spacing: 20) {
            HStack(alignment: .center, spacing: 12) {
                BedsideIconBadge(systemName: "waveform")
                VStack(alignment: .leading, spacing: 3) {
                    Text("念语句挑战")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Bedside.text)
                    Text(speechSubtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Bedside.subtext)
                }
                Spacer()
                Image(systemName: speechController.state == .matched ? "checkmark.circle.fill" : "mic.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(speechController.state == .matched ? Bedside.green : Bedside.amber)
                    .symbolEffect(.pulse, options: .repeating, value: speechController.transcript)
            }

            VStack(spacing: 10) {
                Text("请清楚念出")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Bedside.subtext)
                    .textCase(.uppercase)
                    .tracking(1.2)
                Text("“\(phrase)”")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundColor(Bedside.text)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.black.opacity(0.22))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Bedside.accent.opacity(0.22), lineWidth: 0.8))
                    )
            }

            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("识别内容")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Bedside.subtext)
                    Spacer()
                    Text("匹配度 \(Int(speechController.similarity * 100))%")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Bedside.amber)
                }
                Text(speechController.transcript.isEmpty ? "等待麦克风输入…" : speechController.transcript)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(speechController.transcript.isEmpty ? Bedside.dim : Bedside.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                ProgressView(value: speechController.similarity)
                    .tint(Bedside.accent)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Bedside.surface.opacity(0.45))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Bedside.sep, lineWidth: 0.7))
            )

            if speechController.canMockComplete {
                Button { speechController.mockRecognizeTargetPhrase() } label: {
                    Label("模拟念出目标语句", systemImage: "text.bubble.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Bedside.amber)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background { LiquidGlassCapsule(style: .card, interactive: true) }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .ringingPanel(radius: 24)
        .padding(.horizontal, 24)
        .onAppear {
            if Self.debugSpeechNoAutoStart {
                speechController.prepareMock(phrase: phrase, onComplete: handleSpeechMatch)
            } else {
                speechController.start(phrase: phrase, onComplete: handleSpeechMatch)
            }
        }
        .onDisappear {
            speechController.stop()
        }
    }

    private var photoCard: some View {
        let target = record.targetPhotoLabel ?? "床头灯"
        let status = photoRecognitionStatus

        return VStack(spacing: 16) {
            HStack {
                Spacer()
                challengeModePill("拍照")
                Spacer()
            }

            if let image = cameraController.capturedImage {
                photoPreview(image: image, target: target)
                photoStatusBanner(status)
                photoActionRow
            } else {
                photoMissionStage(target: target)

                Button { cameraController.requestCameraAccessThenOpen() } label: {
                    Label("拍摄", systemImage: "camera.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.82))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule(style: .continuous).fill(Bedside.accent))
                }
                .buttonStyle(.plain)

                if cameraController.canMockCapture {
                    Button { cameraController.mockCapture(targetLabel: target) } label: {
                        Label("模拟拍摄", systemImage: "photo.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Bedside.dim)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(22)
        .ringingPanel(radius: 24)
        .padding(.horizontal, 24)
        .fullScreenCover(isPresented: $cameraController.isShowingCamera) {
            CameraCaptureView(
                onImage: { cameraController.accept(image: $0, targetLabel: target) },
                onCancel: { cameraController.isShowingCamera = false }
            )
            .ignoresSafeArea()
        }
        .onChange(of: cameraController.state) { _, state in
            handlePhotoStateChange(state)
        }
    }

    private func photoMissionStage(target: String) -> some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Bedside.accent.opacity(0.20),
                                Color.white.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Bedside.accent.opacity(0.22), lineWidth: 0.9)
                    )

                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 88, weight: .light))
                    .foregroundStyle(Bedside.accent.opacity(0.13))
                    .offset(y: -8)

                VStack(spacing: 10) {
                    Text(target)
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(Bedside.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
                }
            }
            .frame(height: 236)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("拍照挑战，目标 \(target)")
    }

    private func photoPreview(image: UIImage, target: String) -> some View {
        ZStack(alignment: .topLeading) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 286)
                .frame(maxWidth: .infinity)
                .clipped()
                .background(Color.black.opacity(0.24))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Bedside.accent.opacity(0.26), lineWidth: 0.9))

            Text(target)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Bedside.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(0.52))
                        .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 0.7))
                )
                .padding(12)
        }
        .accessibilityLabel("已拍摄照片预览，目标 \(target)")
    }

    private func photoStatusBanner(_ status: (title: String, detail: String, icon: String, color: Color)) -> some View {
        HStack(spacing: 10) {
            Image(systemName: status.icon)
                .font(.system(size: 18, weight: .bold))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(status.title)
                    .font(.system(size: 18, weight: .bold))
                Text(status.detail)
                    .font(.system(size: 12.5, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)
                    .opacity(0.84)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(status.color)
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(status.color.opacity(0.13))
                .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(status.color.opacity(0.22), lineWidth: 0.8))
        )
    }

    private var photoActionRow: some View {
        Button { cameraController.retake() } label: {
            Label("重拍", systemImage: "arrow.triangle.2.circlepath.camera")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Bedside.amber)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background { LiquidGlassCapsule(style: .card, interactive: true) }
        }
        .buttonStyle(.plain)
        .disabled(cameraController.state == .analyzing || cameraController.state == .matched)
    }

    private var photoRecognitionStatus: (title: String, detail: String, icon: String, color: Color) {
        switch cameraController.state {
        case .matched:
            return ("已匹配", "识别通过，正在完成挑战", "checkmark.circle.fill", Bedside.green)
        case .analyzing, .captured:
            return ("识别中", "正在判断照片是否命中目标", "hourglass", Bedside.amber)
        case .rejected:
            return ("未匹配，请重拍", "没有识别到目标物", "xmark.circle.fill", Bedside.red)
        case .unavailable(let reason):
            return ("未匹配，请重拍", reason, "exclamationmark.triangle.fill", Bedside.red)
        default:
            return ("识别中", "等待照片识别结果", "hourglass", Bedside.amber)
        }
    }

    private func handlePhotoStateChange(_ state: CameraChallengeController.State) {
        guard state == .matched, !photoCompletionScheduled else { return }
        photoCompletionScheduled = true
        let generation = photoCompletionGeneration
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled, photoCompletionGeneration == generation else { return }
            onCorrect()
        }
    }

    private var memoryCard: some View {
        VStack(spacing: 18) {
            Text("记忆游戏")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Bedside.text)
            Text("按顺序点亮图案")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Bedside.subtext)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                ForEach(0..<4) { index in
                    Button {
                        memoryInput.append(index)
                        if memoryInput.count == record.memoryPattern.count {
                            if memoryInput == record.memoryPattern {
                                onCorrect()
                            } else {
                                memoryInput = []
                                withAnimation(.spring()) { result = false }
                            }
                        }
                    } label: {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Bedside.accent.opacity(record.memoryPattern.contains(index) ? 0.16 : 0.08))
                            .overlay(
                                Text("\((record.memoryPattern.firstIndex(of: index) ?? index) + 1)")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(Bedside.amber)
                            )
                            .frame(height: 86)
                    }
                    .buttonStyle(.plain)
                }
            }

            if result == false {
                Text("顺序不对，再来一次")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Bedside.red)
            }
        }
        .padding(24)
        .ringingPanel(radius: 24)
        .padding(.horizontal, 24)
    }

    private var speechSubtitle: String {
        let repeatCount = Alarm.clampedSpeechRepeatCount(record.speechRepeatCount)
        if repeatCount <= 1 { return speechController.state.message }
        return "第 \(min(speechCompletedCount + 1, repeatCount)) / \(repeatCount) 遍 · \(speechController.state.message)"
    }

    private var currentQuestion: MathQuestion? {
        guard record.questions.indices.contains(questionIndex) else { return nil }
        return record.questions[questionIndex]
    }

    private func handleSpeechMatch() {
        let repeatCount = Alarm.clampedSpeechRepeatCount(record.speechRepeatCount)
        speechCompletedCount += 1
        if speechCompletedCount >= repeatCount {
            onCorrect()
            return
        }
        let phrase = record.phrase ?? "我已经醒了，今天也要准时开始"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            if Self.debugSpeechNoAutoStart {
                speechController.prepareMock(phrase: phrase, onComplete: handleSpeechMatch)
            } else {
                speechController.start(phrase: phrase, onComplete: handleSpeechMatch)
            }
        }
    }

    private func checkAnswer() {
        let correct = Int(answer) == currentQuestion?.answer
        withAnimation(.spring()) { result = correct }
        if correct {
            if questionIndex + 1 < record.questions.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    questionIndex += 1
                    answer = ""
                    withAnimation { result = nil }
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { onCorrect() }
            }
        } else {
            answer = ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { withAnimation { result = nil } }
        }
    }
}

private extension View {
    func ringingPanel(radius: CGFloat) -> some View {
        background { LiquidGlassPanel(radius: radius, style: .hero) }
    }
}

struct RingingAmbientBackground: View {
    var body: some View {
        ZStack {
            BedsideAmbientBackground()
            VStack {
                Spacer()
                Circle()
                    .fill(Bedside.accent.opacity(0.26))
                    .frame(width: 280, height: 120)
                    .blur(radius: 45)
                    .offset(y: 58)
            }
        }
    }
}

#Preview {
    RingingView(
        record: ChallengeRecord(
            alarmId: nil,
            type: .math,
            questions: [
                MathQuestion(prompt: "14 × 8 + 45 = ?", answer: 157),
                MathQuestion(prompt: "8 + 15 = ?", answer: 23),
                MathQuestion(prompt: "12 + 19 = ?", answer: 31)
            ],
            phrase: nil,
            targetPhotoLabel: nil,
            memoryPattern: [],
            difficulty: .medium,
            startedAt: Date()
        ),
        onCorrect: {},
        onEmergencyClose: {}
    )
}
