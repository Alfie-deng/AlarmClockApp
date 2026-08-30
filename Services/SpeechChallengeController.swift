import AVFoundation
import Foundation
import Speech

struct SpeechPhraseMatcher {
    let targetPhrase: String
    let minimumSimilarity: Double
    
    init(targetPhrase: String, minimumSimilarity: Double = 0.72) {
        self.targetPhrase = targetPhrase
        self.minimumSimilarity = minimumSimilarity
    }
    
    var normalizedTarget: String {
        Self.normalized(targetPhrase)
    }
    
    func matches(_ transcript: String) -> Bool {
        let target = normalizedTarget
        let spoken = Self.normalized(transcript)
        guard !target.isEmpty, !spoken.isEmpty else { return false }
        if spoken.contains(target) || target.contains(spoken), min(spoken.count, target.count) >= max(4, target.count / 2) {
            return true
        }
        return similarity(between: spoken, and: target) >= minimumSimilarity
    }
    
    func similarityScore(for transcript: String) -> Double {
        similarity(between: Self.normalized(transcript), and: normalizedTarget)
    }
    
    static func normalized(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "zh_Hans_CN"))
            .filter { character in
                character.isLetter || character.isNumber || "一二三四五六七八九十百千万今天准时开始已经醒了要".contains(character)
            }
    }
    
    private func similarity(between lhs: String, and rhs: String) -> Double {
        guard !lhs.isEmpty, !rhs.isEmpty else { return 0 }
        let distance = Self.levenshtein(Array(lhs), Array(rhs))
        return 1 - (Double(distance) / Double(max(lhs.count, rhs.count)))
    }
    
    private static func levenshtein(_ lhs: [Character], _ rhs: [Character]) -> Int {
        if lhs.isEmpty { return rhs.count }
        if rhs.isEmpty { return lhs.count }
        var previous = Array(0...rhs.count)
        var current = Array(repeating: 0, count: rhs.count + 1)
        for i in 1...lhs.count {
            current[0] = i
            for j in 1...rhs.count {
                let cost = lhs[i - 1] == rhs[j - 1] ? 0 : 1
                current[j] = min(
                    previous[j] + 1,
                    current[j - 1] + 1,
                    previous[j - 1] + cost
                )
            }
            previous = current
        }
        return previous[rhs.count]
    }
}

@MainActor
final class SpeechChallengeController: ObservableObject {
    enum State: Equatable {
        case idle
        case requestingPermission
        case listening
        case matched
        case unavailable(String)
        case failed(String)
        
        var message: String {
            switch self {
            case .idle: return "准备监听"
            case .requestingPermission: return "正在请求语音权限"
            case .listening: return "正在听你念出来"
            case .matched: return "识别通过"
            case .unavailable(let reason), .failed(let reason): return reason
            }
        }
    }
    
    @Published private(set) var state: State = .idle
    @Published private(set) var transcript: String = ""
    @Published private(set) var similarity: Double = 0
    
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh_CN"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var matcher = SpeechPhraseMatcher(targetPhrase: "")
    private var onComplete: (() -> Void)?
    private var recognitionGeneration = UUID()
    
    var canMockComplete: Bool {
        if ProcessInfo.processInfo.arguments.contains("--debugSpeechMock") { return true }
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    func prepareMock(phrase: String, onComplete: @escaping () -> Void) {
        stopRecognitionOnly()
        recognitionGeneration = UUID()
        self.onComplete = onComplete
        matcher = SpeechPhraseMatcher(targetPhrase: phrase)
        transcript = ""
        similarity = 0
        state = .idle
    }
    
    func start(phrase: String, onComplete: @escaping () -> Void) {
        prepareMock(phrase: phrase, onComplete: onComplete)
        guard recognizer != nil else {
            state = .unavailable("当前系统没有可用的中文语音识别器")
            return
        }
        guard recognizer?.isAvailable == true else {
            state = .unavailable("语音识别服务暂不可用")
            return
        }
        state = .requestingPermission
        let generation = recognitionGeneration
        requestPermissions { [weak self] granted in
            guard let self else { return }
            guard self.recognitionGeneration == generation else { return }
            if granted {
                self.beginRecognition()
            } else {
                self.state = .unavailable("需要开启语音识别和麦克风权限")
            }
        }
    }
    
    func stop() {
        recognitionGeneration = UUID()
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        onComplete = nil
        if state == .listening { state = .idle }
    }
    
    func mockRecognizeTargetPhrase() {
        accept(transcript: matcher.targetPhrase)
    }
    
    private func requestPermissions(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { speechStatus in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { micGranted in
                    Task { @MainActor in
                        completion(speechStatus == .authorized && micGranted)
                    }
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { micGranted in
                    Task { @MainActor in
                        completion(speechStatus == .authorized && micGranted)
                    }
                }
            }
        }
    }
    
    private func beginRecognition() {
        stopRecognitionOnly()
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            recognitionRequest = request
            
            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
                request?.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            state = .listening
            
            recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }
                Task { @MainActor in
                    if let result {
                        self.accept(transcript: result.bestTranscription.formattedString)
                    }
                    if let error, self.state != .matched {
                        self.state = .failed("语音识别中断：\(error.localizedDescription)")
                        self.stopRecognitionOnly()
                    }
                }
            }
        } catch {
            state = .failed("无法启动麦克风：\(error.localizedDescription)")
            stopRecognitionOnly()
        }
    }
    
    private func accept(transcript newTranscript: String) {
        guard state != .matched else { return }
        transcript = newTranscript
        similarity = matcher.similarityScore(for: newTranscript)
        if matcher.matches(newTranscript) {
            state = .matched
            stopRecognitionOnly()
            let completion = onComplete
            onComplete = nil
            completion?()
        }
    }
    
    private func stopRecognitionOnly() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
    }
}
