import Foundation

enum ChallengeType: String, CaseIterable, Identifiable, Codable {
    case math = "数学题"
    case shake = "摇手机"
    case speak = "念语句"
    case photo = "拍照"
    case memory = "记忆游戏"
    
    var id: String { rawValue }
    
    static var supportedCases: [ChallengeType] { [.math, .shake, .speak, .photo] }
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
        case .photo: return "拍摄指定物品才能关闹钟"
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
        snoozeMinutes: Int = 5
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
        self.snoozeMinutes = snoozeMinutes
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        time = try container.decode(Date.self, forKey: .time)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        requiresChallenge = try container.decodeIfPresent(Bool.self, forKey: .requiresChallenge) ?? true
        challengeType = try container.decodeIfPresent(ChallengeType.self, forKey: .challengeType) ?? .math
        mathDifficulty = try container.decodeIfPresent(MathDifficulty.self, forKey: .mathDifficulty) ?? .medium
        label = try container.decodeIfPresent(String.self, forKey: .label) ?? "起床"
        soundName = try container.decodeIfPresent(String.self, forKey: .soundName) ?? "温柔晨光"
        tag = try container.decodeIfPresent(String.self, forKey: .tag) ?? "工作日"
        repeatDays = try container.decodeIfPresent(Set<Int>.self, forKey: .repeatDays) ?? [2, 3, 4, 5, 6]
        snoozeMinutes = try container.decodeIfPresent(Int.self, forKey: .snoozeMinutes) ?? 5
    }
    
    var formattedTime: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f.string(from: time)
    }
    
    var formattedPeriod: String {
        let f = DateFormatter()
        f.dateFormat = "a"
        return f.string(from: time)
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
        
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = Locale(identifier: "zh_Hans_CN")
        weekdayFormatter.dateFormat = "EEE"
        let weekday = weekdayFormatter.string(from: target)
        
        switch dayDelta {
        case 0:
            return "今天 \(weekday)"
        case 1:
            return "明天 \(weekday)"
        default:
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "zh_Hans_CN")
            dateFormatter.dateFormat = "M月d日"
            return "\(dateFormatter.string(from: target)) \(weekday)"
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
    let startedAt: Date
    var requiresChallenge: Bool = true
    var isCompleted: Bool = false
    
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
