import Foundation
import Testing
@testable import LettuceDecide

@MainActor
struct RecipeDetailViewModelTests {
    private func recipe(_ required: [RecipeIngredient]) -> Recipe {
        Recipe(id: 1, title: "Test Dish", requiredIngredients: required)
    }

    @Test func ingredientStatusesClassifyHaveShortAndMissingFromCurrentPantry() {
        let cooked = recipe([
            RecipeIngredient(id: 1, name: "flour", requiredQuantity: 200, unit: .grams),
            RecipeIngredient(id: 2, name: "sugar", requiredQuantity: 100, unit: .grams),
            RecipeIngredient(id: 3, name: "butter", requiredQuantity: 50, unit: .grams),
        ])
        let store = InMemoryPantryStore(initial: [
            PantryIngredient(ingredientName: "flour", quantity: 500, unit: .grams, storageLocation: .pantry),
            PantryIngredient(ingredientName: "sugar", quantity: 40, unit: .grams, storageLocation: .pantry),
        ])
        let viewModel = RecipeDetailViewModel(recipe: cooked, pantryStore: store)

        let statuses = viewModel.ingredientStatuses
        #expect(statuses.map(\.kind) == [.have, .shortBy(have: 40, unit: .grams), .missing])
        // Every row carries the recipe's required amount + unit, never blank.
        #expect(statuses.map(\.requiredAmount) == ["200 g", "100 g", "50 g"])
    }

    @Test func ingredientStatusesReReflectThePantryAfterItChanges() {
        let cooked = recipe([
            RecipeIngredient(id: 1, name: "flour", requiredQuantity: 200, unit: .grams),
            RecipeIngredient(id: 2, name: "sugar", requiredQuantity: 100, unit: .grams),
        ])
        let store = InMemoryPantryStore(initial: [
            PantryIngredient(ingredientName: "flour", quantity: 500, unit: .grams, storageLocation: .pantry)
        ])
        let viewModel = RecipeDetailViewModel(recipe: cooked, pantryStore: store)
        #expect(viewModel.ingredientStatuses.map(\.kind) == [.have, .missing])

        // The cook adds the missing ingredient elsewhere; the checklist catches up with no
        // manual reload.
        store.save(store.load() + [
            PantryIngredient(ingredientName: "sugar", quantity: 60, unit: .grams, storageLocation: .pantry)
        ])

        #expect(viewModel.ingredientStatuses.map(\.kind) == [.have, .shortBy(have: 60, unit: .grams)])
    }

    @Test func markAsCookedDeductsAndReportsSuccess() throws {
        let store = InMemoryPantryStore(initial: [
            PantryIngredient(ingredientName: "flour", quantity: 500, unit: .grams, storageLocation: .pantry)
        ])
        let viewModel = RecipeDetailViewModel(
            recipe: recipe([RecipeIngredient(id: 1, name: "flour", requiredQuantity: 200, unit: .grams)]),
            pantryStore: store
        )

        viewModel.markAsCooked()

        #expect(viewModel.cookAlert?.didCook == true)
        #expect(store.load().first?.quantity == 300)
    }

    @Test func markAsCookedSurfacesInsufficientQuantityWithoutSaving() {
        let store = InMemoryPantryStore(initial: [
            PantryIngredient(ingredientName: "flour", quantity: 100, unit: .grams, storageLocation: .pantry)
        ])
        let viewModel = RecipeDetailViewModel(
            recipe: recipe([RecipeIngredient(id: 1, name: "flour", requiredQuantity: 250, unit: .grams)]),
            pantryStore: store
        )

        viewModel.markAsCooked()

        #expect(viewModel.cookAlert?.didCook == false)
        #expect(store.load().first?.quantity == 100)
    }
}
