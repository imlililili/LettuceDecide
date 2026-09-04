import Foundation

/// One day's recorded busyness.
///
/// Real-world meaning: "on this day, I expect to be this busy". Written by the daily
/// quick-pick (one day at a time) and by the weekly planner's "set this week" flow (seven
/// days in a row).
///
/// Business rule: a day has exactly one busyness level at a time. The `date` is pinned to
/// the start of its day at construction, so "the same day" is a plain `==` on `date`, and
/// `RecordBusynessUseCase` replaces an existing entry rather than storing a second one.
struct ScheduleEntry: Identifiable, Codable, Equatable {
    /// The day this entry is for, normalised to the start of the day.
    let date: Date
    let busyness: BusynessLevel

    var id: Date { date }

    init(date: Date, busyness: BusynessLevel, calendar: Calendar = .current) {
        self.date = calendar.startOfDay(for: date)
        self.busyness = busyness
    }
}
