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

    /// Genuinely cross-group (weight vs volume) — flour in grams can't be safely compared to
    /// flour in cups (density varies per ingredient), so this must still require manual
    /// review after the volume-conversion fix, not be loosened along with it.
    @Test func updateInventory_skipsAndReportsIngredientsMeasuredInAnUnconvertibleUnit() throws {
        let flour = PantryIngredient(ingredientName: "flour", quantity: 500, unit: .grams, storageLocation: .pantry)
        let store = InMemoryPantryStore(initial: [flour])
        let cooked = recipe([RecipeIngredient(id: 1, name: "flour", requiredQuantity: 2, unit: .cups)])

        let outcome = try UpdateInventoryAfterCookingUseCase(store: store)
            .execute(result(recipe: cooked, matched: [flour]))

        #expect(outcome.deducted.isEmpty)
        #expect(outcome.needsManualReview.map(\.name) == ["flour"])
        #expect(store.load().first?.quantity == 500)
    }

    // MARK: - Same-measurement-group volume conversion

    /// The actual regression: pantry storage now normalises volume ingredients to
    /// millilitres (feature/pantry-volume-ml-normalization), but a recipe's own required
    /// unit is whatever Spoonacular reported (often tablespoons/teaspoons/cups) — so an exact
    /// unit match became the common case that *fails*, sending nearly every volume
    /// ingredient to "update by hand" instead of deducting normally.
    @Test func updateInventory_deductsWhenTheRecipeAndPantryUnitsAreDifferentButConvertible() throws {
        let oliveOil = PantryIngredient(ingredientName: "olive oil", quantity: 480, unit: .millilitres, storageLocation: .pantry)
        let store = InMemoryPantryStore(initial: [oliveOil])
        let cooked = recipe([RecipeIngredient(id: 1, name: "olive oil", requiredQuantity: 2, unit: .tablespoons)])

        let outcome = try UpdateInventoryAfterCookingUseCase(store: store)
            .execute(result(recipe: cooked, matched: [oliveOil]))

        #expect(outcome.deducted == ["olive oil"])
        #expect(outcome.needsManualReview.isEmpty)
        // 480ml - (2 tbsp = 30ml) = 450ml.
        #expect(store.load().first?.quantity == 450)
    }

    @Test func updateInventory_insufficientQuantityErrorComparesInThePantrysOwnUnit() {
        let oliveOil = PantryIngredient(ingredientName: "olive oil", quantity: 10, unit: .millilitres, storageLocation: .pantry)
        let store = InMemoryPantryStore(initial: [oliveOil])
        let cooked = recipe([RecipeIngredient(id: 1, name: "olive oil", requiredQuantity: 2, unit: .tablespoons)])

        // 2 tbsp = 30ml needed, only 10ml on hand -> the error compares like-for-like (ml),
        // not "10ml vs 2 tbsp" which would read as nonsense.
        #expect(throws: InventoryUpdateError.insufficientQuantity(ingredientName: "olive oil", available: 10, requested: 30)) {
            try UpdateInventoryAfterCookingUseCase(store: store)
                .execute(result(recipe: cooked, matched: [oliveOil]))
        }
    }

    /// Locks the exact scenario from the user's screenshot: a recipe needing salt, olive oil,
    /// and paprika all deducts normally once the pantry's (post-normalisation) millilitres
    /// lines are correctly compared against the recipe's own tablespoon/teaspoon amounts.
    @Test func updateInventory_deductsSaltOliveOilAndPaprikaDespiteDifferingVolumeUnits() throws {
        let salt = PantryIngredient(ingredientName: "salt", quantity: 100, unit: .millilitres, storageLocation: .pantry)
        let oliveOil = PantryIngredient(ingredientName: "olive oil", quantity: 480, unit: .millilitres, storageLocation: .pantry)
        let paprika = PantryIngredient(ingredientName: "paprika", quantity: 60, unit: .millilitres, storageLocation: .pantry)
        let store = InMemoryPantryStore(initial: [salt, oliveOil, paprika])
        let cooked = recipe([
            RecipeIngredient(id: 1, name: "salt", requiredQuantity: 1, unit: .teaspoons),
            RecipeIngredient(id: 2, name: "olive oil", requiredQuantity: 2, unit: .tablespoons),
            RecipeIngredient(id: 3, name: "paprika", requiredQuantity: 1, unit: .teaspoons),
        ])

        let outcome = try UpdateInventoryAfterCookingUseCase(store: store)
            .execute(result(recipe: cooked, matched: [salt, oliveOil, paprika]))

        #expect(Set(outcome.deducted) == ["salt", "olive oil", "paprika"])
        #expect(outcome.needsManualReview.isEmpty)
        let pantry = store.load()
        #expect(pantry.first { $0.ingredientName == "salt" }?.quantity == 95) // 100 - 5ml (1 tsp)
        #expect(pantry.first { $0.ingredientName == "olive oil" }?.quantity == 450) // 480 - 30ml (2 tbsp)
        #expect(pantry.first { $0.ingredientName == "paprika" }?.quantity == 55) // 60 - 5ml (1 tsp)
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
