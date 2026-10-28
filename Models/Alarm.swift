import Foundation

private enum AlarmDateFormatters {
    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter
    }()

    static let period: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "a"
        return formatter
    }()

    static let zhWeekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "EEE"
        return formatter
    }()

    static let zhMonthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "M月d日"
        return formatter
    }()
}


enum ChallengeType: String, CaseIterable, Identifiable, Codable {
    case math = "数学题"
    case shake = "摇手机"
    case speak = "念语句"
    case photo = "拍照"
    case memory = "记忆游戏"

    var id: String { rawValue }

    static var supportedCases: [ChallengeType] { [.math, .shake, .photo] }
    static var betaCases: [ChallengeType] { allCases.filter { !supportedCases.contains($0) } }

    var isSupported: Bool {
        Self.supportedCases.contains(self)
    }

    var icon: String {
        switch self {
        case .math: return "plus.forwardslash.minus"
        case .shake: return "iphone.radiowaves.left.and.right"
        case .speak: return "waveform"
        case .photo: return "camera"
        case .memory: return "brain.head.profile"
        }
    }

    var description: String {
        switch self {
        case .math: return "答对数学题才能关闹钟"
        case .shake: return "用力摇晃手机才能关闹钟"
        case .speak: return "念出指定语句才能关闹钟"
        case .photo: return "拍到指定目标才能关闹钟"
        case .memory: return "记住图案顺序才能关闹钟"
        }
    }
}

enum MathDifficulty: String, CaseIterable, Identifiable, Codable {
    case easy = "简单"
    case medium = "中等"
    case hard = "困难"

    var id: String { rawValue }
}

struct AlarmSound: Identifiable, Equatable {
    let id: String
    let title: String
    let fileName: String

    static let options: [AlarmSound] = [
        AlarmSound(id: "gentleMorning", title: "温柔晨光", fileName: "gentle-morning.caf"),
        AlarmSound(id: "forestBird", title: "森林鸟鸣", fileName: "forest-bird.caf"),
        AlarmSound(id: "oceanBreeze", title: "海边微风", fileName: "ocean-breeze.caf"),
        AlarmSound(id: "classicBell", title: "经典铃声", fileName: "classic-bell.caf")
    ]

    static func option(named name: String) -> AlarmSound {
        options.first { $0.title == name } ?? options[0]
    }
}

struct Alarm: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var time: Date
    var isEnabled: Bool = true
    var requiresChallenge: Bool = true
    var challengeType: ChallengeType = .math
    var mathDifficulty: MathDifficulty = .medium
    var label: String = "起床"
    var soundName: String = "温柔晨光"
    var tag: String = "工作日"
    var repeatDays: Set<Int> = [2, 3, 4, 5, 6]
    var snoozeMinutes: Int = 5
    var mathQuestionCount: Int = 3
    var shakeRequiredCount: Int = 20
    var speechPhrase: String = "我已经醒了，今天也要准时开始"
    var speechRepeatCount: Int = 1
    var photoTargetLabel: String = "床头灯"

    enum CodingKeys: String, CodingKey {
        case id
        case time
        case isEnabled
        case requiresChallenge
        case challengeType
        case mathDifficulty
        case label
        case soundName
        case tag
        case repeatDays
        case snoozeMinutes
        case mathQuestionCount
        case shakeRequiredCount
        case speechPhrase
        case speechRepeatCount
        case photoTargetLabel
    }

    init(
        id: UUID = UUID(),
        time: Date,
        isEnabled: Bool = true,
        requiresChallenge: Bool = true,
        challengeType: ChallengeType = .math,
        mathDifficulty: MathDifficulty = .medium,
        label: String = "起床",
        soundName: String = "温柔晨光",
        tag: String = "工作日",
        repeatDays: Set<Int> = [2, 3, 4, 5, 6],
        snoozeMinutes: Int = 5,
        mathQuestionCount: Int = 3,
        shakeRequiredCount: Int = 20,
        speechPhrase: String = "我已经醒了，今天也要准时开始",
        speechRepeatCount: Int = 1,
        photoTargetLabel: String = "床头灯"
    ) {
        self.id = id
        self.time = time
        self.isEnabled = isEnabled
        self.requiresChallenge = requiresChallenge
        self.challengeType = challengeType
        self.mathDifficulty = mathDifficulty
        self.label = label
        self.soundName = soundName
        self.tag = tag
        self.repeatDays = repeatDays
        self.snoozeMinutes = Self.clampedSnoozeMinutes(snoozeMinutes)
        self.mathQuestionCount = Self.clampedMathQuestionCount(mathQuestionCount)
        self.shakeRequiredCount = Self.clampedShakeRequiredCount(shakeRequiredCount)
        self.speechPhrase = speechPhrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "我已经醒了，今天也要准时开始" : speechPhrase
        self.speechRepeatCount = Self.clampedSpeechRepeatCount(speechRepeatCount)
        self.photoTargetLabel = Self.normalizedPhotoTarget(photoTargetLabel)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        time = try container.decode(Date.self, forKey: .time)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        requiresChallenge = try container.decodeIfPresent(Bool.self, forKey: .requiresChallenge) ?? true
        let decodedChallenge = try container.decodeIfPresent(ChallengeType.self, forKey: .challengeType) ?? .math
        challengeType = decodedChallenge.isSupported ? decodedChallenge : .math
        mathDifficulty = try container.decodeIfPresent(MathDifficulty.self, forKey: .mathDifficulty) ?? .medium
        label = try container.decodeIfPresent(String.self, forKey: .label) ?? "起床"
        soundName = try container.decodeIfPresent(String.self, forKey: .soundName) ?? "温柔晨光"
        tag = try container.decodeIfPresent(String.self, forKey: .tag) ?? "工作日"
        repeatDays = try container.decodeIfPresent(Set<Int>.self, forKey: .repeatDays) ?? [2, 3, 4, 5, 6]
        snoozeMinutes = Self.clampedSnoozeMinutes(try container.decodeIfPresent(Int.self, forKey: .snoozeMinutes) ?? 5)
        mathQuestionCount = Self.clampedMathQuestionCount(try container.decodeIfPresent(Int.self, forKey: .mathQuestionCount) ?? 3)
        shakeRequiredCount = Self.clampedShakeRequiredCount(try container.decodeIfPresent(Int.self, forKey: .shakeRequiredCount) ?? 20)
        let decodedPhrase = try container.decodeIfPresent(String.self, forKey: .speechPhrase) ?? "我已经醒了，今天也要准时开始"
        speechPhrase = decodedPhrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "我已经醒了，今天也要准时开始" : decodedPhrase
        speechRepeatCount = Self.clampedSpeechRepeatCount(try container.decodeIfPresent(Int.self, forKey: .speechRepeatCount) ?? 1)
        photoTargetLabel = Self.normalizedPhotoTarget(try container.decodeIfPresent(String.self, forKey: .photoTargetLabel) ?? "床头灯")
    }

    var formattedTime: String {
        AlarmDateFormatters.time.string(from: time)
    }

    var formattedPeriod: String {
        AlarmDateFormatters.period.string(from: time)
    }

    var repeatWeekdays: Set<Int> {
        Alarm.normalizedRepeatWeekdays(from: repeatDays)
    }

    func nextOccurrence(after referenceDate: Date = Date(), calendar: Calendar = .current) -> Date {
        let timeParts = calendar.dateComponents([.hour, .minute], from: time)
        let repeatWeekdays = repeatWeekdays

        for offset in 0..<8 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: referenceDate) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            if !repeatWeekdays.isEmpty, !repeatWeekdays.contains(weekday) { continue }

            var targetParts = calendar.dateComponents([.year, .month, .day], from: day)
            targetParts.hour = timeParts.hour
            targetParts.minute = timeParts.minute
            targetParts.second = 0

            guard let candidate = calendar.date(from: targetParts) else { continue }
            if candidate > referenceDate {
                return candidate
            }
        }

        var fallbackParts = calendar.dateComponents([.year, .month, .day], from: referenceDate)
        fallbackParts.hour = timeParts.hour
        fallbackParts.minute = timeParts.minute
        fallbackParts.second = 0
        let fallback = calendar.date(from: fallbackParts) ?? referenceDate
        return calendar.date(byAdding: .day, value: 1, to: fallback) ?? fallback
    }

    func nextOccurrenceText(after referenceDate: Date = Date(), calendar: Calendar = .current) -> String {
        let target = nextOccurrence(after: referenceDate, calendar: calendar)
        let dayDelta = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: referenceDate),
            to: calendar.startOfDay(for: target)
        ).day ?? 0

        let weekday = AlarmDateFormatters.zhWeekday.string(from: target)

        switch dayDelta {
        case 0:
            return "今天 \(weekday)"
        case 1:
            return "明天 \(weekday)"
        default:
            return "\(AlarmDateFormatters.zhMonthDay.string(from: target)) \(weekday)"
        }
    }

    static func normalizedRepeatWeekdays(from storedDays: Set<Int>) -> Set<Int> {
        guard !storedDays.isEmpty else { return [] }

        if storedDays.contains(0) {
            return Set(storedDays.compactMap(Self.weekdayFromLegacyOffset))
        }

        if storedDays == [1, 2, 3, 4, 5] {
            return [2, 3, 4, 5, 6]
        }

        return Set(storedDays.filter { (1...7).contains($0) })
    }

    static func clampedMathQuestionCount(_ count: Int) -> Int {
        min(max(count, 1), 5)
    }

    static func clampedShakeRequiredCount(_ count: Int) -> Int {
        min(max(count, 5), 80)
    }

    static func clampedSpeechRepeatCount(_ count: Int) -> Int {
        min(max(count, 1), 3)
    }

    static func clampedSnoozeMinutes(_ minutes: Int) -> Int {
        min(max(minutes, 1), 30)
    }

    static let supportedPhotoTargets = ["床头灯", "洗手台", "书桌", "门"]

    static func normalizedPhotoTarget(_ target: String) -> String {
        let trimmed = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "床头灯" }
        // 系统识图没有「牙刷」这个类别，旧闹钟改成同在卫生间的洗手台。
        if trimmed == "牙刷" { return "洗手台" }
        return supportedPhotoTargets.contains(trimmed) ? trimmed : "床头灯"
    }

    static func weekdayFromLegacyOffset(_ offset: Int) -> Int? {
        switch offset {
        case 0: return 2
        case 1: return 3
        case 2: return 4
        case 3: return 5
        case 4: return 6
        case 5: return 7
        case 6: return 1
        default: return nil
        }
    }
}

struct ChallengeRecord: Identifiable {
    let id = UUID()
    let alarmId: UUID?
    let type: ChallengeType
    let questions: [MathQuestion]
    let phrase: String?
    let targetPhotoLabel: String?
    let memoryPattern: [Int]
    let difficulty: MathDifficulty
    let soundName: String
    let shakeRequiredCount: Int
    let speechRepeatCount: Int
    let startedAt: Date
    var requiresChallenge: Bool = true
    var isCompleted: Bool = false

    init(
        alarmId: UUID?,
        type: ChallengeType,
        questions: [MathQuestion],
        phrase: String?,
        targetPhotoLabel: String?,
        memoryPattern: [Int],
        difficulty: MathDifficulty,
        soundName: String = "温柔晨光",
        shakeRequiredCount: Int = 20,
        speechRepeatCount: Int = 1,
        startedAt: Date,
        requiresChallenge: Bool = true,
        isCompleted: Bool = false
    ) {
        self.alarmId = alarmId
        self.type = type
        self.questions = questions
        self.phrase = phrase
        self.targetPhotoLabel = targetPhotoLabel
        self.memoryPattern = memoryPattern
        self.difficulty = difficulty
        self.soundName = soundName
        self.shakeRequiredCount = Alarm.clampedShakeRequiredCount(shakeRequiredCount)
        self.speechRepeatCount = Alarm.clampedSpeechRepeatCount(speechRepeatCount)
        self.startedAt = startedAt
        self.requiresChallenge = requiresChallenge
        self.isCompleted = isCompleted
    }

    var question: String { questions.first?.prompt ?? "" }
    var answer: Int? { questions.first?.answer }
}

struct MathQuestion: Identifiable, Codable, Equatable {
    var id = UUID()
    let prompt: String
    let answer: Int
}

struct WakeSession: Identifiable, Codable, Equatable {
    var id = UUID()
    let alarmId: UUID?
    let alarmLabel: String
    let challengeType: ChallengeType
    let mathDifficulty: MathDifficulty
    let startedAt: Date
    let completedAt: Date
    let durationSeconds: Int
    var mood: WakeMood?
    var note: String
    let emergencyClosed: Bool

    var completedDay: Date {
        Calendar.current.startOfDay(for: completedAt)
    }
}

enum WakeMood: String, CaseIterable, Identifiable, Codable {
    case great = "很棒"
    case normal = "一般"
    case tired = "困倦"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .great: return "face.smiling"
        case .normal: return "face.dashed"
        case .tired: return "powersleep"
        }
    }
}
