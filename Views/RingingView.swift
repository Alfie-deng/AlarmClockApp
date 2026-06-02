import SwiftUI

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
                        Text("滑动进入数学题，让大脑先开机")
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
                        Text("稍后提醒 5 分钟")
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
    let onCorrect: () -> Void
    let onSnooze: () -> Void
    
    @State private var answer = ""
    @State private var result: Bool? = nil
    @State private var questionIndex = 0
    @State private var memoryInput: [Int] = []
    @StateObject private var shakeController = ShakeChallengeController(requiredCount: RingingView.debugShakeRequiredCount)
    @StateObject private var speechController = SpeechChallengeController()
    
    private var time: String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: Date())
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
                Text(time)
                    .font(.system(size: 82, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .glow(Bedside.amber)
                BedsidePill(text: "挑战模式：\(record.type.rawValue)", icon: "shield.checkered")
                    .padding(.top, 10)
                
                Spacer()
                
                // 挑战卡片
                challengeContent
                
                Spacer()
                
                // 稍后提醒
                Button { onSnooze() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 13))
                        Text("紧急关闭（将计入失败）").font(.system(size: 14))
                    }
                    .foregroundColor(Bedside.dim)
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background { LiquidGlassCapsule(style: .card, interactive: true) }
                }
                .buttonStyle(.plain)
                .padding(.bottom, 40)
            }
        }
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
            case .photo, .memory: unavailableCard
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
                Text("当前正式可用的是数学题挑战。这个模式还需要接入真实能力后再开放。")
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
            HStack(alignment: .center, spacing: 12) {
                BedsideIconBadge(systemName: "plus.forwardslash.minus")
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("数学题挑战")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Bedside.text)
                    Text("第 \(questionIndex + 1) / \(max(record.questions.count, 1)) 题 · 保持清醒")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Bedside.subtext)
                }
                
                Spacer()
                
                Text(String(format: "%02d", questionIndex + 1))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Bedside.amber)
                    .frame(width: 42, height: 30)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Bedside.accent.opacity(0.12))
                            .overlay(Capsule().stroke(Bedside.accent.opacity(0.22), lineWidth: 0.6))
                    )
            }
            
            VStack(spacing: 16) {
                Text("解答以下题目")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Bedside.subtext)
                    .textCase(.uppercase)
                    .tracking(1.2)
                
                Text(currentQuestion?.prompt ?? record.question)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.75)
                    .foregroundColor(Bedside.text)
                    .shadow(color: Bedside.amber.opacity(0.18), radius: 10)
                
                answerField
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            
            VStack(spacing: 9) {
                ForEach(0..<3) { row in
                    HStack(spacing: 9) {
                        ForEach(1...3, id: \.self) { col in
                            keyBtn("\(row * 3 + col)") { answer.append("\(row * 3 + col)") }
                        }
                    }
                }
                HStack(spacing: 9) {
                    keyBtn(icon: "delete.left") { if !answer.isEmpty { answer.removeLast() } }
                    keyBtn("0") { answer.append("0") }
                    keyBtn(icon: "checkmark") { checkAnswer() }.disabled(answer.isEmpty)
                }
            }
            .padding(10)
            
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
    
    private func keyBtn(_ title: String? = nil, icon: String? = nil, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                LiquidGlassPanel(radius: 16, style: .card, interactive: !disabled)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill((icon == "checkmark" ? Bedside.accent : Color.white).opacity(disabled ? 0.035 : 0.055))
                            .blendMode(.screen)
                    }
                    .opacity(disabled ? 0.55 : 1)
                    .shadow(color: icon == "checkmark" ? Bedside.accent.opacity(0.14) : .black.opacity(0.12), radius: 6, x: 0, y: 3)
                
                if let t = title {
                    Text(t)
                        .font(.system(size: 23, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(disabled ? Bedside.dim : Bedside.text)
                } else if let i = icon {
                    Image(systemName: i)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(i == "checkmark" ? Bedside.accent : Bedside.subtext)
                }
            }
            .frame(height: 50)
            .frame(maxWidth: .infinity)
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
        VStack(spacing: 22) {
            HStack(alignment: .center, spacing: 12) {
                BedsideIconBadge(systemName: "iphone.radiowaves.left.and.right")
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("摇手机挑战")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Bedside.text)
                    Text(shakeController.isMotionAvailable ? "用力摇晃手机，清醒到位再关闭" : "当前设备不支持传感器，使用模拟按钮验证")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Bedside.subtext)
                }
                
                Spacer()
                
                Text("\(shakeController.count)/\(shakeController.requiredCount)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Bedside.amber)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Bedside.accent.opacity(0.12))
                            .overlay(Capsule().stroke(Bedside.accent.opacity(0.22), lineWidth: 0.6))
                    )
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
                    .font(.system(size: 58, weight: .light))
                    .foregroundStyle(Bedside.accent)
                    .symbolEffect(.pulse, options: .repeating, value: shakeController.count)
                Text(shakeController.isRunning ? "传感器监听中" : "准备开始")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Bedside.subtext)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            
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
                    Text(speechController.state.message)
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
                speechController.prepareMock(phrase: phrase, onComplete: onCorrect)
            } else {
                speechController.start(phrase: phrase, onComplete: onCorrect)
            }
        }
        .onDisappear {
            speechController.stop()
        }
    }
    
    private var photoCard: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 52))
                .foregroundStyle(Bedside.accent)
            Text("拍照挑战")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Bedside.text)
            Text("请拍摄：\(record.targetPhotoLabel ?? "床头灯")")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Bedside.subtext)
            Button("模拟拍照完成") { onCorrect() }
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
    
    private var currentQuestion: MathQuestion? {
        guard record.questions.indices.contains(questionIndex) else { return nil }
        return record.questions[questionIndex]
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
        onSnooze: {}
    )
}
