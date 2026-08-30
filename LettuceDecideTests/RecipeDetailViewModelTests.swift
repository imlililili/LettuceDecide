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

        let kinds = viewModel.ingredientStatuses.map(\.kind)
        #expect(kinds[0] == .have)
        #expect(kinds[1] == .shortBy(have: 40, need: 100, unit: .grams))
        #expect(kinds[2] == .missing)
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
