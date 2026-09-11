import Foundation

/// Business operation: the cook confirms they want to eat a specific recipe on a specific
/// Week Plan day.
///
/// Two things happen, both durable:
/// 1. the day + recipe is recorded via `ConfirmedMealStoring` (replacing any earlier choice
///    for that same day) — this is what lets the Home dashboard, and the shopping list built
///    from it, survive a tab switch or an app relaunch;
/// 2. whatever the recipe still needs once the *current* pantry is applied is merged into the
///    persisted shopping list, netted against every other day already confirmed so the same
///    physical stock is never offered to two different days (see `PantryShortfallCalculator`).
///    A day that's re-confirmed with a different recipe does not retroactively remove what its
///    old recipe already added to the shopping list — there is no shopping-list edit surface
///    yet to reconcile that against, and changing one's mind about a day is expected to be rare.
///
/// Nothing here touches the real pantry — confirming still only means "the cook wants to eat
/// this that day," not "the cook cooked it." That only happens through
/// `UpdateInventoryAfterCookingUseCase`, once the day has arrived.
///
/// No error type: every input is already-validated domain data and nothing here can fail —
/// same reasoning as `RecordBusynessUseCase` and `AddMissingIngredientsToShoppingListUseCase`.
struct ConfirmPlannedMealUseCase {
    let confirmedMealStore: ConfirmedMealStoring
    let pantryStore: PantryStoring
    let addToShoppingList: AddMissingIngredientsToShoppingListUseCase

    @discardableResult
    func execute(recipe: Recipe, date: Date, calendar: Calendar = .current, now: Date = Date()) -> ConfirmedMeal {
        let meal = ConfirmedMeal(date: date, recipe: recipe, confirmedAt: now, calendar: calendar)

        // Every other already-confirmed day's ingredients are drawn down from a virtual copy
        // of the pantry *before* this day's shortfall is calculated, in a fixed (date) order —
        // so two confirmed days sharing an ingredient don't each get offered the same physical
        // stock as if the other day didn't exist.
        let otherConfirmedMeals = confirmedMealStore.loadConfirmedMeals()
            .filter { $0.id != meal.id }
            .sorted { $0.date < $1.date }

        confirmedMealStore.confirm(meal)

        var virtualPantry = pantryStore.load()
        for other in otherConfirmedMeals {
            _ = PantryShortfallCalculator.stillNeeded(for: other.recipe, from: &virtualPantry, now: now)
        }

        let shortfall = PantryShortfallCalculator.stillNeeded(for: recipe, from: &virtualPantry, now: now)
        if !shortfall.isEmpty {
            addToShoppingList.execute(adding: shortfall)
        }

        return meal
    }
}
