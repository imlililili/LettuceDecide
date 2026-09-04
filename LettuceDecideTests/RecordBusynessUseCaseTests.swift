import Foundation
import Testing
@testable import LettuceDecide

struct RecordBusynessUseCaseTests {
    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    /// 2023-11-14T00:00:00Z — a UTC day boundary, so added hours stay inside day 1.
    private let day1 = Date(timeIntervalSince1970: 1_699_920_000)
    private var day2: Date { day1.addingTimeInterval(86_400) }

    private func makeUseCase(_ initial: [ScheduleEntry] = []) -> (RecordBusynessUseCase, InMemoryScheduleStore) {
        let store = InMemoryScheduleStore(initial: initial)
        return (RecordBusynessUseCase(store: store), store)
    }

    @Test func recordsANewEntryAndPersistsIt() {
        let (useCase, store) = makeUseCase()

        let schedule = useCase.execute(date: day1, busyness: .busy, calendar: utc)

        #expect(schedule.count == 1)
        #expect(schedule.first?.busyness == .busy)
        #expect(store.loadEntries().count == 1)
    }

    @Test func replacesTheExistingEntryForTheSameDay() {
        let (useCase, store) = makeUseCase([ScheduleEntry(date: day1, busyness: .relaxed, calendar: utc)])

        let laterInTheSameDay = day1.addingTimeInterval(8 * 3600)
        let schedule = useCase.execute(date: laterInTheSameDay, busyness: .busy, calendar: utc)

        #expect(schedule.count == 1)
        #expect(schedule.first?.busyness == .busy)
        #expect(store.loadEntries().count == 1)
    }

    @Test func keepsSeparateEntriesForDifferentDaysSortedByDate() {
        let (useCase, _) = makeUseCase()

        _ = useCase.execute(date: day2, busyness: .relaxed, calendar: utc)
        let schedule = useCase.execute(date: day1, busyness: .busy, calendar: utc)

        #expect(schedule.map(\.busyness) == [.busy, .relaxed])
        #expect(schedule.first?.date == utc.startOfDay(for: day1))
    }
}
