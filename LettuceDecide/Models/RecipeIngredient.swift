import Foundation

/// One ingredient a recipe *requires*, in the amount it calls for.
///
/// Real-world meaning: a line on a recipe's ingredient list.
///
/// This is a separate type from `PantryIngredient` on purpose: "an ingredient the recipe
/// needs" and "an ingredient the cook owns" are different concepts that only sometimes line
/// up, and collapsing them into one struct would hide that. `id` is Spoonacular's ingredient
/// identifier, not a per-recipe line number.
struct RecipeIngredient: Identifiable, Codable, Equatable, Hashable {
    let id: Int
    let name: String
    let requiredQuantity: Double
    let unit: IngredientUnit

    init(id: Int, name: String, requiredQuantity: Double, unit: IngredientUnit) {
        self.id = id
        self.name = name
        self.requiredQuantity = requiredQuantity
        self.unit = unit
    }
}
