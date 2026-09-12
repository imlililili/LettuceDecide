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
    /// `true` when Spoonacular's own unit for this line wasn't really a measure of quantity
    /// (the diagnosed case: `"servings"`, e.g. "4 servings" of green onion on one recipe
    /// line) — a data-quality quirk in Spoonacular's ingredient parsing, not a genuine count.
    /// `requiredQuantity` must not be trusted, summed, or compared against the pantry when
    /// this is `true`; callers show an honest "amount unclear" instead of a confident-looking
    /// wrong number (see `UpdateInventoryAfterCookingUseCase` and the shopping-list builders).
    let quantityIsUncertain: Bool

    init(
        id: Int,
        name: String,
        requiredQuantity: Double,
        unit: IngredientUnit,
        quantityIsUncertain: Bool = false
    ) {
        self.id = id
        self.name = name
        self.requiredQuantity = requiredQuantity
        self.unit = unit
        self.quantityIsUncertain = quantityIsUncertain
    }

    /// Tolerant of JSON written before `quantityIsUncertain` existed (e.g. a previously
    /// cached recipe search) — missing means "not flagged", not a decode failure.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        requiredQuantity = try c.decode(Double.self, forKey: .requiredQuantity)
        unit = try c.decode(IngredientUnit.self, forKey: .unit)
        quantityIsUncertain = try c.decodeIfPresent(Bool.self, forKey: .quantityIsUncertain) ?? false
    }
}
