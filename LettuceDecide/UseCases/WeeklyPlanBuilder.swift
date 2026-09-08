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
/// 4. virtually deducts that recipe's ingredients using the same unit-match-only rule as
///    `UpdateInventoryAfterCookingUseCase`, and rolls whatever the pantry can't cover into
///    the shopping list.
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

            for shortfall in consume(pick.recipe, from: &virtualPantry, now: now) {
                shoppingList.addMerging(shortfall)
            }
        }

        return WeeklyMealPlan(days: days, shoppingList: shoppingList)
    }

    /// Deducts what `recipe` uses from `pantry` (a local copy) and returns the amounts the
    /// cook still has to buy.
    ///
    /// - An ingredient the pantry doesn't have at all → the full required amount is bought.
    /// - An ingredient the pantry has, but in a different unit from the recipe → left
    ///   untouched and **not** treated as missing. The cook has it; the app just can't
    ///   compare the amounts (grams ↔ cups depends on the ingredient), so it says nothing,
    ///   the same way `UpdateInventoryAfterCookingUseCase` defers to a manual review.
    /// - An ingredient the pantry has enough of → deducted; a line that hits exactly zero is
    ///   removed.
    /// - An ingredient the pantry has some of, but not enough → drained to zero (line
    ///   removed) and the difference is bought.
    private static func consume(
        _ recipe: Recipe,
        from pantry: inout [PantryIngredient],
        now: Date
    ) -> [ShoppingListItem] {
        var toBuy: [ShoppingListItem] = []

        for required in recipe.requiredIngredients {
            let key = required.name.normalizedIngredientName
            guard let index = pantry.firstIndex(where: {
                $0.ingredientName.normalizedIngredientName == key
            }) else {
                toBuy.append(shoppingItem(for: required, quantity: required.requiredQuantity, now: now))
                continue
            }

            let line = pantry[index]
            guard line.unit == required.unit else { continue }

            if line.quantity >= required.requiredQuantity {
                let remaining = line.quantity - required.requiredQuantity
                if remaining == 0 {
                    pantry.remove(at: index)
                } else {
                    pantry[index].quantity = remaining
                }
            } else {
                pantry.remove(at: index)
                toBuy.append(shoppingItem(
                    for: required,
                    quantity: required.requiredQuantity - line.quantity,
                    now: now
                ))
            }
        }

        return toBuy
    }

    private static func shoppingItem(
        for required: RecipeIngredient,
        quantity: Double,
        now: Date
    ) -> ShoppingListItem {
        ShoppingListItem(
            ingredientName: required.name,
            requiredQuantity: quantity,
            unit: required.unit,
            dateAdded: now
        )
    }
}
