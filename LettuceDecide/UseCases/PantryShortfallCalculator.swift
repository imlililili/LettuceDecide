import Foundation

/// Pure, no-I/O arithmetic for "how much of this recipe still needs buying once the pantry's
/// current stock is applied" — shared by the weekly planner (aggregating a whole week's
/// shortfalls day by day) and confirming a single planned meal (netting against every other
/// day already confirmed, so the same physical stock isn't offered to two different days).
///
/// Rules (same "unit-match-only, never guess a conversion" stance as
/// `UpdateInventoryAfterCookingUseCase`):
/// - a required ingredient whose quantity is flagged uncertain (see
///   `RecipeIngredient.quantityIsUncertain`) is never compared against the pantry at all —
///   there's no trustworthy number to compare with — and goes straight onto the shopping
///   list as its own honest "amount unclear" line;
/// - an ingredient the pantry doesn't have at all → the full required amount is needed;
/// - an ingredient the pantry has, but in a different unit → left alone, not treated as
///   missing (the cook has it; the app just can't compare grams to cups);
/// - an ingredient the pantry has enough of → nothing is needed, and that amount is drawn
///   down from `pantry` so a second recipe sharing the ingredient sees what's left;
/// - an ingredient the pantry has some of, but not enough → drained to zero and the
///   difference is needed.
enum PantryShortfallCalculator {
    /// - Parameter pantry: a **local, mutable copy** — never the real store. It is drawn down
    ///   in place so a caller can thread the same virtual pantry across several recipes (a
    ///   week's worth of days, or a set of already-confirmed meals) and get a shortfall that
    ///   accounts for what earlier recipes already claimed, instead of double-counting the
    ///   same physical stock.
    static func stillNeeded(
        for recipe: Recipe,
        from pantry: inout [PantryIngredient],
        now: Date = Date()
    ) -> [ShoppingListItem] {
        var toBuy: [ShoppingListItem] = []

        for required in recipe.requiredIngredients {
            if required.quantityIsUncertain {
                toBuy.append(shoppingItem(for: required, quantity: required.requiredQuantity, now: now))
                continue
            }

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
            dateAdded: now,
            ingredientId: required.id,
            quantityIsUncertain: required.quantityIsUncertain
        )
    }
}
