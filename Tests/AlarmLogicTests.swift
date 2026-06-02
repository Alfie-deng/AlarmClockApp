import XCTest
@testable import AlarmClockApp

final class AlarmLogicTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
    
    func testNextOccurrenceRespectsWeekdayRepeat() throws {
        let reference = try date(year: 2026, month: 6, day: 2, hour: 8, minute: 0) // Tuesday
        let alarmTime = try date(year: 2026, month: 1, day: 1, hour: 7, minute: 30)
        let alarm = Alarm(time: alarmTime, repeatDays: [2]) // Monday
        
        let next = alarm.nextOccurrence(after: reference, calendar: calendar)
        
        XCTAssertEqual(calendar.component(.weekday, from: next), 2)
        XCTAssertEqual(calendar.component(.day, from: next), 8)
        XCTAssertEqual(calendar.component(.hour, from: next), 7)
        XCTAssertEqual(calendar.component(.minute, from: next), 30)
    }
    
    func testOneShotAlarmUsesNextCalendarDayWhenTodayHasPassed() throws {
        let reference = try date(year: 2026, month: 6, day: 2, hour: 8, minute: 0)
        let alarmTime = try date(year: 2026, month: 1, day: 1, hour: 7, minute: 30)
        let alarm = Alarm(time: alarmTime, repeatDays: [])
        
        let next = alarm.nextOccurrence(after: reference, calendar: calendar)
        
        XCTAssertEqual(calendar.component(.day, from: next), 3)
        XCTAssertEqual(calendar.component(.hour, from: next), 7)
        XCTAssertEqual(calendar.component(.minute, from: next), 30)
    }
    
    func testLegacyRepeatOffsetsMapToSystemWeekdays() {
        XCTAssertEqual(Alarm.normalizedRepeatWeekdays(from: [0, 1, 2, 3, 4]), [2, 3, 4, 5, 6])
        XCTAssertEqual(Alarm.normalizedRepeatWeekdays(from: [0, 6]), [2, 1])
    }
    
    func testSupportedChallengeCasesExposeRealImplementedModes() {
        XCTAssertEqual(ChallengeType.supportedCases, [.math, .shake, .speak])
        XCTAssertFalse(ChallengeType.betaCases.contains(.shake))
        XCTAssertFalse(ChallengeType.betaCases.contains(.speak))
        XCTAssertTrue(ChallengeType.betaCases.contains(.photo))
        XCTAssertTrue(ChallengeType.betaCases.contains(.memory))
    }
    
    func testSpeechPhraseMatcherNormalizesPunctuationAndAcceptsClosePhrase() {
        let matcher = SpeechPhraseMatcher(targetPhrase: "我已经醒了，今天也要准时开始")
        
        XCTAssertTrue(matcher.matches("我已经醒了 今天也要准时开始"))
        XCTAssertTrue(matcher.matches("我已经醒了今天也要准时开始。"))
        XCTAssertGreaterThan(matcher.similarityScore(for: "我已经醒了今天也要准时开始"), 0.9)
        XCTAssertFalse(matcher.matches("我还想睡觉 明天再说"))
    }
    
    func testShakeTrackerRequiresThresholdAndCooldown() throws {
        var tracker = ShakeChallengeTracker(requiredCount: 2, threshold: 2.0, cooldown: 0.5)
        let start = try date(year: 2026, month: 6, day: 2, hour: 7, minute: 30)
        
        XCTAssertFalse(tracker.recordAcceleration(x: 1.0, y: 0.5, z: 0.2, at: start))
        XCTAssertEqual(tracker.count, 0)
        
        XCTAssertTrue(tracker.recordAcceleration(x: 2.2, y: 0, z: 0, at: start))
        XCTAssertEqual(tracker.count, 1)
        
        XCTAssertFalse(tracker.recordAcceleration(x: 2.2, y: 0, z: 0, at: start.addingTimeInterval(0.2)))
        XCTAssertEqual(tracker.count, 1)
        
        XCTAssertTrue(tracker.recordAcceleration(x: 2.2, y: 0, z: 0, at: start.addingTimeInterval(0.6)))
        XCTAssertEqual(tracker.count, 2)
        XCTAssertTrue(tracker.isComplete)
        XCTAssertEqual(tracker.progress, 1)
        
        XCTAssertFalse(tracker.recordAcceleration(x: 3.0, y: 0, z: 0, at: start.addingTimeInterval(1.2)))
        XCTAssertEqual(tracker.count, 2)
    }
    
    func testWakeSessionStatsIgnoreEmergencyClosuresAndIncludeCurrentSession() throws {
        let monday = try date(year: 2026, month: 6, day: 1, hour: 7, minute: 30)
        let tuesday = try date(year: 2026, month: 6, day: 2, hour: 7, minute: 30)
        let emergency = makeSession(completedAt: tuesday, emergencyClosed: true)
        let mondaySession = makeSession(completedAt: monday)
        let tuesdaySession = makeSession(completedAt: tuesday)
        
        let completed = WakeSessionStats.completedSessions([mondaySession, emergency], including: tuesdaySession)
        
        XCTAssertEqual(completed.count, 2)
        XCTAssertEqual(WakeSessionStats.currentStreak(sessions: completed, endingOn: tuesday, calendar: calendar), 2)
        XCTAssertEqual(WakeSessionStats.bestStreak(sessions: completed, calendar: calendar), 2)
    }
    
    private func makeSession(completedAt: Date, emergencyClosed: Bool = false) -> WakeSession {
        WakeSession(
            alarmId: nil,
            alarmLabel: "起床",
            challengeType: .math,
            mathDifficulty: .medium,
            startedAt: completedAt.addingTimeInterval(-90),
            completedAt: completedAt,
            durationSeconds: 90,
            mood: nil,
            note: "",
            emergencyClosed: emergencyClosed
        )
    }
    
    private func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) throws -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.timeZone = calendar.timeZone
        return try XCTUnwrap(calendar.date(from: components))
    }
}
