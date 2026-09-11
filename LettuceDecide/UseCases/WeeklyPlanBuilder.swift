import Foundation

/// Pure assignment logic for the weekly planner — no network, no storage, no clock beyond
/// the `now` it is handed.
///
/// It walks the week in date order and, for each day:
/// 1. drops candidates that break that day's `BusynessLevel` cap, or that were already
///    assigned earlier in the week;
/// 2. ranks what's left with `PantryMatcher` against a **virtual** pantry that shrinks as
///    days are planned;
/// 3. assigns the top match, or `nil` if nothing qualifies (an honest "no match", never a
///    repeat or a cap-breaking filler);
/// 4. virtually deducts that recipe's ingredients via `PantryShortfallCalculator` (the same
///    unit-match-only rule as `UpdateInventoryAfterCookingUseCase`), and rolls whatever the
///    pantry can't cover into the shopping list.
///
/// The `pantry` passed in is never mutated — the deduction runs on a local copy. Generating
/// a plan is a preview; only cooking a day touches the real pantry.
enum WeeklyPlanBuilder {
    static func build(
        candidates: [PantryRecipeCandidate],
        busyness: [ScheduleEntry],
        startingFrom pantry: [PantryIngredient],
        now: Date = Date()
    ) -> WeeklyMealPlan {
        var virtualPantry = pantry
        var assignedRecipeIDs: Set<Int> = []
        var days: [DayMealPlan] = []
        var shoppingList: [ShoppingListItem] = []
        let matcher = PantryMatcher()

        for entry in busyness.sorted(by: { $0.date < $1.date }) {
            let eligible = candidates.filter { candidate in
                !assignedRecipeIDs.contains(candidate.recipe.id)
                    && entry.busyness.permits(candidate.recipe)
            }
            let ranked = matcher.match(candidates: eligible, against: virtualPantry, now: now)

            guard let pick = ranked.first else {
                days.append(DayMealPlan(id: entry.date, busyness: entry.busyness, assignedRecipe: nil))
                continue
            }

            assignedRecipeIDs.insert(pick.recipe.id)
            days.append(DayMealPlan(id: entry.date, busyness: entry.busyness, assignedRecipe: pick.recipe))

            for shortfall in PantryShortfallCalculator.stillNeeded(for: pick.recipe, from: &virtualPantry, now: now) {
                shoppingList.addMerging(shortfall)
            }
        }

        return WeeklyMealPlan(days: days, shoppingList: shoppingList)
    }
}
