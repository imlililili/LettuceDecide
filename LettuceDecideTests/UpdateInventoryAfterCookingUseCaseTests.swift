import Foundation
import Testing
@testable import LettuceDecide

struct UpdateInventoryAfterCookingUseCaseTests {
    private func recipe(_ required: [RecipeIngredient]) -> Recipe {
        Recipe(id: 42, title: "Test Bake", requiredIngredients: required)
    }

    private func result(recipe: Recipe, matched: [PantryIngredient]) -> PantryMatchResult {
        PantryMatchResult(
            id: recipe.id,
            recipe: recipe,
            matchedIngredients: matched,
            missingIngredients: [],
            usesExpiringIngredients: false
        )
    }

    @Test func updateInventory_deductsQuantity_afterRecipeIsCooked() throws {
        let flour = PantryIngredient(ingredientName: "flour", quantity: 500, unit: .grams, storageLocation: .pantry)
        let store = InMemoryPantryStore(initial: [flour])
        let cooked = recipe([RecipeIngredient(id: 1, name: "flour", requiredQuantity: 200, unit: .grams)])

        let outcome = try UpdateInventoryAfterCookingUseCase(store: store)
            .execute(result(recipe: cooked, matched: [flour]))

        #expect(outcome.deducted == ["flour"])
        #expect(store.load().first?.quantity == 300)
    }

    @Test func updateInventory_fails_whenRequestedQuantityExceedsAvailable() {
        let flour = PantryIngredient(ingredientName: "flour", quantity: 100, unit: .grams, storageLocation: .pantry)
        let store = InMemoryPantryStore(initial: [flour])
        let cooked = recipe([RecipeIngredient(id: 1, name: "flour", requiredQuantity: 250, unit: .grams)])

        #expect(throws: InventoryUpdateError.insufficientQuantity(ingredientName: "flour", available: 100, requested: 250)) {
            try UpdateInventoryAfterCookingUseCase(store: store)
                .execute(result(recipe: cooked, matched: [flour]))
        }
        // Nothing was saved.
        #expect(store.load().first?.quantity == 100)
    }

    @Test func updateInventory_skipsAndReportsIngredientsMeasuredInADifferentUnit() throws {
        let flour = PantryIngredient(ingredientName: "flour", quantity: 500, unit: .grams, storageLocation: .pantry)
        let store = InMemoryPantryStore(initial: [flour])
        let cooked = recipe([RecipeIngredient(id: 1, name: "flour", requiredQuantity: 2, unit: .cups)])

        let outcome = try UpdateInventoryAfterCookingUseCase(store: store)
            .execute(result(recipe: cooked, matched: [flour]))

        #expect(outcome.deducted.isEmpty)
        #expect(outcome.needsManualReview.map(\.name) == ["flour"])
        #expect(store.load().first?.quantity == 500)
    }

    /// A real-inventory-corruption risk found while diagnosing the "onion 200 pcs" shopping
    /// list bug: the same untrustworthy "servings" quantity that inflated the shopping list
    /// could also deduct a fabricated amount of *real* pantry stock on Mark as Cooked. An
    /// uncertain quantity must route to manual review, never be deducted — reusing the exact
    /// mechanism `.needsManualReview` already has for a cross-unit mismatch.
    @Test func updateInventory_skipsAndReportsIngredientsWithAnUncertainQuantity() throws {
        let onion = PantryIngredient(ingredientName: "onion", quantity: 3, unit: .pieces, storageLocation: .pantry)
        let store = InMemoryPantryStore(initial: [onion])
        let cooked = recipe([
            RecipeIngredient(id: 1, name: "onion", requiredQuantity: 12, unit: .pieces, quantityIsUncertain: true)
        ])

        let outcome = try UpdateInventoryAfterCookingUseCase(store: store)
            .execute(result(recipe: cooked, matched: [onion]))

        #expect(outcome.deducted.isEmpty)
        #expect(outcome.needsManualReview.map(\.name) == ["onion"])
        // The real pantry is untouched — nothing was deducted based on the bad number.
        #expect(store.load().first?.quantity == 3)
    }

    @Test func updateInventory_removesLineWhenItReachesExactlyZero() throws {
        let eggs = PantryIngredient(ingredientName: "eggs", quantity: 3, unit: .pieces, storageLocation: .fridge)
        let store = InMemoryPantryStore(initial: [eggs])
        let cooked = recipe([RecipeIngredient(id: 1, name: "egg", requiredQuantity: 3, unit: .pieces)])

        let outcome = try UpdateInventoryAfterCookingUseCase(store: store)
            .execute(result(recipe: cooked, matched: [eggs]))

        #expect(outcome.deducted == ["eggs"])
        #expect(store.load().isEmpty)
    }

    @Test func updateInventory_fails_whenAMatchedLineWasRemovedSinceTheRecommendation() {
        let stale = PantryIngredient(ingredientName: "butter", quantity: 250, unit: .grams, storageLocation: .fridge)
        let store = InMemoryPantryStore(initial: [])
        let cooked = recipe([RecipeIngredient(id: 1, name: "butter", requiredQuantity: 50, unit: .grams)])

        #expect(throws: InventoryUpdateError.ingredientNotFound(name: "butter")) {
            try UpdateInventoryAfterCookingUseCase(store: store)
                .execute(result(recipe: cooked, matched: [stale]))
        }
    }
}
