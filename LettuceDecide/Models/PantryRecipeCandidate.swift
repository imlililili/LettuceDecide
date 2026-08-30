import Foundation

/// A recipe returned by the recipe service in response to a pantry-driven search, together
/// with the service's own verdict on which of the supplied pantry ingredients it uses and
/// which further ingredients it needs.
///
/// The used / missing split comes from the service on purpose — matching free-text
/// ingredient names is exactly the kind of fuzzy problem this app defers to Spoonacular
/// rather than re-implementing. `PantryMatcher` only maps the "used" names back onto real
/// pantry lines (for expiry) and ranks the results.
struct PantryRecipeCandidate: Equatable {
    let recipe: Recipe
    /// Names of the supplied pantry ingredients this recipe uses, as the service tags them.
    let usedIngredientNames: [String]
    /// Ingredients the recipe needs beyond what was supplied.
    let missedIngredients: [RecipeIngredient]
}
