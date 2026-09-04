import Foundation

/// Business operation: the cook records (or changes) how busy they expect to be on one day.
///
/// Used by both entry points — the daily quick-pick on the Recommendations screen, and the
/// weekly planner's "set this week" flow calling it once per day.
///
/// There is no dedicated error type on purpose: a `Date` and a `BusynessLevel` are both
/// value types that cannot be malformed, so the only "rule" to enforce is the one-entry-
/// per-day replacement, which is not a failure.
///
/// Business rule: recording a level for a day that already has one **replaces** it — a day
/// only ever holds one busyness level. Entries are kept sorted by date.
struct RecordBusynessUseCase {
    let store: ScheduleStoring

    /// - Returns: the full schedule after the change, so callers can refresh their view.
    @discardableResult
    func execute(
        date: Date,
        busyness: BusynessLevel,
        calendar: Calendar = .current
    ) -> [ScheduleEntry] {
        let entry = ScheduleEntry(date: date, busyness: busyness, calendar: calendar)

        var entries = store.loadEntries()
        if let index = entries.firstIndex(where: { $0.date == entry.date }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
        entries.sort { $0.date < $1.date }

        store.save(entries)
        return entries
    }
}
