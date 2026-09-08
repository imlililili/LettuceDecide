import Foundation

/// One line of the shopping list: an ingredient the cook still needs, in the amount the
/// week's plan (or a single recipe) calls for.
///
/// Real-world meaning: a line the cook would write on a scrap of paper before going to the
/// shop.
///
/// Business rule (dedupe, carried over from the pantry inventory rule): two lines with the
/// same normalised name **and** the same unit describe the same purchase and are merged
/// into one line, their quantities added. Two lines with the same name but different units
/// stay separate — the app never guesses cross-unit conversions (grams ↔ cups depends on
/// the ingredient), so it never silently combines across units. `mergeKey` is that identity.
/// The merge itself is applied by `AddMissingIngredientsToShoppingListUseCase`.
struct ShoppingListItem: Identifiable, Codable, Equatable {
    let id: UUID
    let ingredientName: String
    var requiredQuantity: Double
    let unit: IngredientUnit
    let dateAdded: Date

    init(
        id: UUID = UUID(),
        ingredientName: String,
        requiredQuantity: Double,
        unit: IngredientUnit,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.ingredientName = ingredientName
        self.requiredQuantity = requiredQuantity
        self.unit = unit
        self.dateAdded = dateAdded
    }

    /// Identity for the dedupe rule: normalised name + unit. Not the same as `id`, which is
    /// per-record.
    var mergeKey: MergeKey {
        MergeKey(normalizedName: ingredientName.normalizedIngredientName, unit: unit)
    }

    struct MergeKey: Hashable {
        let normalizedName: String
        let unit: IngredientUnit
    }
}

extension Array where Element == ShoppingListItem {
    /// Adds `item` under the dedupe rule: an existing line with the same `mergeKey`
    /// (normalised name + unit) has its quantity summed; anything else is appended. Different
    /// units for the same name stay as separate lines.
    ///
    /// Shared by `WeeklyPlanBuilder` (aggregating a week's shortfalls) and
    /// `AddMissingIngredientsToShoppingListUseCase` (merging into the saved list).
    mutating func addMerging(_ item: ShoppingListItem) {
        if let index = firstIndex(where: { $0.mergeKey == item.mergeKey }) {
            self[index].requiredQuantity += item.requiredQuantity
        } else {
            append(item)
        }
    }
}
