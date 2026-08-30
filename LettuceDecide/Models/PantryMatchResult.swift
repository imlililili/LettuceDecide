import Foundation

/// The domain answer to "can I make this with what I have?" for one recipe.
///
/// This is not a technical DTO — it is exactly what the Recommendations screen shows the
/// cook. It is always built from real pantry and recipe data, never estimated, because the
/// PRD's transparency rule requires the app to be able to explain *why* a recipe was
/// suggested.
///
/// Business rule: `matchPercentage` counts whether an ingredient is present, **not whether
/// there is enough of it**. A recipe can be 100% matched and still need more flour than the
/// pantry holds — the Recipe Detail screen is responsible for showing that quantity gap.
struct PantryMatchResult: Identifiable, Equatable {
    /// The recipe's id.
    let id: Int
    let recipe: Recipe
    /// Pantry lines this recipe draws on (per the recipe service's own used/missing split).
    let matchedIngredients: [PantryIngredient]
    /// Ingredients the recipe needs that the pantry does not have.
    let missingIngredients: [RecipeIngredient]
    /// Whether at least one matched pantry line is expiring soon or already expired —
    /// the signal the ranking uses to float "use it up" recipes to the top.
    let usesExpiringIngredients: Bool

    /// Fraction of the recipe's ingredients the cook already has, 0...1.
    var matchPercentage: Double {
        let total = matchedIngredients.count + missingIngredients.count
        guard total > 0 else { return 0 }
        return Double(matchedIngredients.count) / Double(total)
    }
}
