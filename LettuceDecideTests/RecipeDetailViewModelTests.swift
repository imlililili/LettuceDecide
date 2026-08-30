import Foundation
import Testing
@testable import LettuceDecide

@MainActor
struct RecipeDetailViewModelTests {
    private func recipe(_ required: [RecipeIngredient]) -> Recipe {
        Recipe(id: 1, title: "Test Dish", requiredIngredients: required)
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

    @Test func ingredientStatusesClassifyHaveShortAndMissing() {
        let cooked = recipe([
            RecipeIngredient(id: 1, name: "flour", requiredQuantity: 200, unit: .grams),
            RecipeIngredient(id: 2, name: "sugar", requiredQuantity: 100, unit: .grams),
            RecipeIngredient(id: 3, name: "butter", requiredQuantity: 50, unit: .grams),
        ])
        let viewModel = RecipeDetailViewModel(
            result: result(recipe: cooked, matched: [
                PantryIngredient(ingredientName: "flour", quantity: 500, unit: .grams, storageLocation: .pantry),
                PantryIngredient(ingredientName: "sugar", quantity: 40, unit: .grams, storageLocation: .pantry),
            ]),
            pantryStore: InMemoryPantryStore()
        )

        let statuses = viewModel.ingredientStatuses
        #expect(statuses.map(\.kind) == [.have, .shortBy(have: 40, unit: .grams), .missing])
        // Every row carries the recipe's required amount + unit, never blank.
        #expect(statuses.map(\.requiredAmount) == ["200 g", "100 g", "50 g"])
    }

    @Test func markAsCookedDeductsAndReportsSuccess() throws {
        let flour = PantryIngredient(ingredientName: "flour", quantity: 500, unit: .grams, storageLocation: .pantry)
        let store = InMemoryPantryStore(initial: [flour])
        let viewModel = RecipeDetailViewModel(
            result: result(
                recipe: recipe([RecipeIngredient(id: 1, name: "flour", requiredQuantity: 200, unit: .grams)]),
                matched: [flour]
            ),
            pantryStore: store
        )

        viewModel.markAsCooked()

        #expect(viewModel.cookAlert?.didCook == true)
        #expect(store.load().first?.quantity == 300)
    }

    @Test func markAsCookedSurfacesInsufficientQuantityWithoutSaving() {
        let flour = PantryIngredient(ingredientName: "flour", quantity: 100, unit: .grams, storageLocation: .pantry)
        let store = InMemoryPantryStore(initial: [flour])
        let viewModel = RecipeDetailViewModel(
            result: result(
                recipe: recipe([RecipeIngredient(id: 1, name: "flour", requiredQuantity: 250, unit: .grams)]),
                matched: [flour]
            ),
            pantryStore: store
        )

        viewModel.markAsCooked()

        #expect(viewModel.cookAlert?.didCook == false)
        #expect(store.load().first?.quantity == 100)
    }
}
