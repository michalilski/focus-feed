import XCTest
@testable import FocusFeed

final class DailyClockTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func time(_ hours: Double, day: Int = 1) -> Date {
        Date(timeIntervalSince1970: Double(day - 1) * 86_400 + hours * 3_600)
    }

    private func newClock() -> DailyClock {
        DailyClock(day: calendar.startOfDay(for: time(0)))
    }

    func testCountsOnlyWhileOpen() {
        var clock = newClock()
        clock.resume(at: time(9), calendar: calendar)
        clock.suspend(at: time(9.1), calendar: calendar)
        clock.resume(at: time(12), calendar: calendar)
        XCTAssertEqual(clock.elapsed(at: time(12.1), calendar: calendar), 12 * 60, accuracy: 0.001)
    }

    func testLongBreaksDoNotResetTheDay() {
        var clock = newClock()
        clock.resume(at: time(9), calendar: calendar)
        clock.suspend(at: time(9.1), calendar: calendar)
        clock.resume(at: time(20), calendar: calendar)
        XCTAssertEqual(clock.elapsed(at: time(20), calendar: calendar), 6 * 60, accuracy: 0.001)
    }

    func testNewDayStartsFromZero() {
        var clock = newClock()
        clock.resume(at: time(9), calendar: calendar)
        clock.suspend(at: time(10), calendar: calendar)
        clock.resume(at: time(8, day: 2), calendar: calendar)
        XCTAssertEqual(clock.elapsed(at: time(8.05, day: 2), calendar: calendar), 3 * 60, accuracy: 0.001)
    }

    func testOpenAcrossMidnightCountsOnlyTheNewDay() {
        var clock = newClock()
        clock.resume(at: time(23.9), calendar: calendar)
        XCTAssertEqual(clock.elapsed(at: time(0.1, day: 2), calendar: calendar), 6 * 60, accuracy: 0.001)
    }

    func testNudgeIsDueAfterFifteenMinutesToday() {
        var clock = newClock()
        clock.resume(at: time(9), calendar: calendar)
        clock.suspend(at: time(9.2), calendar: calendar)
        clock.resume(at: time(15), calendar: calendar)
        XCTAssertFalse(clock.isNudgeDue(at: time(15 + 2.9 / 60), calendar: calendar))
        XCTAssertTrue(clock.isNudgeDue(at: time(15.05), calendar: calendar))
    }

    func testSnoozeGivesFiveMoreMinutes() {
        var clock = newClock()
        clock.resume(at: time(9), calendar: calendar)
        clock.snooze(at: time(9.25), calendar: calendar)
        XCTAssertFalse(clock.isNudgeDue(at: time(9.33), calendar: calendar))
        XCTAssertTrue(clock.isNudgeDue(at: time(9 + 20.0 / 60), calendar: calendar))
    }

    func testSnoozeDoesNotCarryIntoTheNextDay() {
        var clock = newClock()
        clock.resume(at: time(9), calendar: calendar)
        clock.snooze(at: time(10), calendar: calendar)
        clock.suspend(at: time(10), calendar: calendar)
        clock.resume(at: time(9, day: 2), calendar: calendar)
        XCTAssertTrue(clock.isNudgeDue(at: time(9.25, day: 2), calendar: calendar))
    }

    func testSurvivesSavingAndLoading() throws {
        var clock = newClock()
        clock.resume(at: time(9), calendar: calendar)
        clock.suspend(at: time(9.1), calendar: calendar)
        let loaded = try JSONDecoder().decode(DailyClock.self, from: JSONEncoder().encode(clock))
        XCTAssertEqual(loaded.elapsed(at: time(11), calendar: calendar), 6 * 60, accuracy: 0.001)
    }
}
