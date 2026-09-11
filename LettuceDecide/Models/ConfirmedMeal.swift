import Foundation

/// A day the cook has confirmed they want to eat a specific recipe.
///
/// This is the durable record behind the Week Plan's "Plan This for {Weekday}" confirmation —
/// what lets the Home dashboard, and the shopping list built from it, survive a tab switch or
/// an app relaunch. Confirming is still not cooking: nothing here ever touches the pantry.
///
/// Same one-record-per-day shape as `ScheduleEntry`: confirming a different recipe for a day
/// that already has one replaces it (see `ConfirmedMealStoring.confirm(_:)`), it never stores
/// a second entry for that day.
struct ConfirmedMeal: Identifiable, Codable, Equatable {
    /// The day this meal is confirmed for, normalised to the start of the day.
    let id: Date
    /// A full snapshot of the recipe at confirm time, not just its id — recipe data comes
    /// from an external API, and the cook must still be able to see (and later mark cooked)
    /// what they confirmed even offline or after the API's own data has since changed.
    let recipe: Recipe
    let confirmedAt: Date

    var date: Date { id }

    init(date: Date, recipe: Recipe, confirmedAt: Date = Date(), calendar: Calendar = .current) {
        self.id = calendar.startOfDay(for: date)
        self.recipe = recipe
        self.confirmedAt = confirmedAt
    }
}
