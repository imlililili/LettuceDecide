import Foundation

/// One day of a generated weekly plan: how busy the cook said they'd be, and the recipe the
/// planner assigned for that day.
///
/// Business rule: `assignedRecipe == nil` is an honest "couldn't find a match for this day"
/// — a recipe that fit the busyness cap and the safety rule, and wasn't already used earlier
/// in the week. It is never a blank slot to be quietly filled with a repeat or with
/// something that breaks a cap.
struct DayMealPlan: Identifiable, Equatable {
    /// The day this plan is for (start of day).
    let id: Date
    let busyness: BusynessLevel
    let assignedRecipe: Recipe?

    var date: Date { id }
}

/// A full seven-day plan generated against the cook's pantry and schedule, plus the shopping
/// list for everything the week still needs once the plan is built.
///
/// This is a **preview**: producing it never touches the real pantry. Only cooking a
/// specific day, through the existing Recipe Detail → Mark as Cooked flow, does that.
struct WeeklyMealPlan: Equatable {
    /// Monday…Sunday, in date order.
    let days: [DayMealPlan]
    /// Missing ingredients aggregated across every assigned day, deduped by name + unit.
    let shoppingList: [ShoppingListItem]
    /// `true` when the candidate pool came from the offline cache rather than a live fetch.
    /// The Week Plan screen surfaces this so a stale plan is never shown as if it were current.
    var isFromCache: Bool = false
}
