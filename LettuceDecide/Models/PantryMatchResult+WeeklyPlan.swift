import Foundation

extension PantryMatchResult {
    /// Builds a match result for `recipe` against the cook's `pantry` by matching normalised
    /// ingredient names.
    ///
    /// The weekly plan carries a bare `Recipe` (no service-provided used/missing split), but
    /// the Recipe Detail screen needs a `PantryMatchResult`. This recomputes that split
    /// against the **real** pantry as it stands now — the honest "what do you have for this
    /// today" view — the same presence-not-quantity rule `PantryMatcher` uses.
    static func matching(
        _ recipe: Recipe,
        against pantry: [PantryIngredient],
        now: Date = Date()
    ) -> PantryMatchResult {
        let requiredKeys = Set(recipe.requiredIngredients.map { $0.name.normalizedIngredientName })
        let matched = pantry.filter { requiredKeys.contains($0.ingredientName.normalizedIngredientName) }
        let matchedKeys = Set(matched.map { $0.ingredientName.normalizedIngredientName })
        let missing = recipe.requiredIngredients.filter {
            !matchedKeys.contains($0.name.normalizedIngredientName)
        }

        return PantryMatchResult(
            id: recipe.id,
            recipe: recipe,
            matchedIngredients: matched,
            missingIngredients: missing,
            usesExpiringIngredients: matched.contains { $0.expiryStatus(asOf: now).needsUsingUp }
        )
    }
}
