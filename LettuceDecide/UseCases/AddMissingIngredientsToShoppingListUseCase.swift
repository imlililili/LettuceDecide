import Foundation

/// Business operation: merge a set of still-needed ingredients into the cook's saved
/// shopping list — the aggregated `WeeklyMealPlan.shoppingList`, or the missing ingredients
/// from one recipe on the Recipe Detail screen.
///
/// No error type: the inputs are already validated `ShoppingListItem`s and the only rule is
/// the dedupe merge (`Array.addMerging` — same name + unit sums, different units stay
/// separate), which cannot fail.
struct AddMissingIngredientsToShoppingListUseCase {
    let store: ShoppingListStoring

    /// - Returns: the full shopping list after the merge, so callers can show a count.
    @discardableResult
    func execute(adding items: [ShoppingListItem]) -> [ShoppingListItem] {
        var list = store.loadItems()
        for item in items {
            list.addMerging(item)
        }
        store.save(list)
        return list
    }

    /// Convenience for the Recipe Detail screen: turn a recipe's still-missing ingredients
    /// into shopping-list lines and merge them in.
    @discardableResult
    func execute(missing ingredients: [RecipeIngredient], now: Date = Date()) -> [ShoppingListItem] {
        execute(adding: ingredients.map {
            ShoppingListItem(
                ingredientName: $0.name,
                requiredQuantity: $0.requiredQuantity,
                unit: $0.unit,
                dateAdded: now,
                ingredientId: $0.id,
                quantityIsUncertain: $0.quantityIsUncertain
            )
        })
    }
}
