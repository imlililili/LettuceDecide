import Foundation
import Testing
@testable import LettuceDecide

struct AddMissingIngredientsToShoppingListUseCaseTests {
    private func item(_ name: String, _ qty: Double, _ unit: IngredientUnit) -> ShoppingListItem {
        ShoppingListItem(ingredientName: name, requiredQuantity: qty, unit: unit)
    }

    @Test func mergesItemsIntoTheSavedListAndPersists() {
        let store = InMemoryShoppingListStore()
        let useCase = AddMissingIngredientsToShoppingListUseCase(store: store)

        let list = useCase.execute(adding: [item("spinach", 200, .grams), item("eggs", 6, .pieces)])

        #expect(list.map(\.ingredientName).sorted() == ["eggs", "spinach"])
        #expect(store.loadItems().count == 2)
    }

    @Test func sumsQuantitiesForTheSameNameAndUnit() {
        let store = InMemoryShoppingListStore(initial: [item("flour", 200, .grams)])
        let useCase = AddMissingIngredientsToShoppingListUseCase(store: store)

        let list = useCase.execute(adding: [item("Flour", 300, .grams)])

        #expect(list.count == 1)
        #expect(list.first?.requiredQuantity == 500)
    }

    @Test func keepsTheSameNameInDifferentUnitsAsSeparateLines() {
        let store = InMemoryShoppingListStore(initial: [item("flour", 200, .grams)])
        let useCase = AddMissingIngredientsToShoppingListUseCase(store: store)

        let list = useCase.execute(adding: [item("flour", 2, .cups)])

        #expect(list.count == 2)
        #expect(Set(list.map(\.unit)) == [.grams, .cups])
    }

    @Test func turnsARecipesMissingIngredientsIntoShoppingLines() {
        let store = InMemoryShoppingListStore()
        let useCase = AddMissingIngredientsToShoppingListUseCase(store: store)

        let list = useCase.execute(missing: [
            RecipeIngredient(id: 1, name: "curry powder", requiredQuantity: 1, unit: .tablespoons),
            RecipeIngredient(id: 2, name: "coconut milk", requiredQuantity: 400, unit: .millilitres),
        ])

        #expect(list.map(\.ingredientName).sorted() == ["coconut milk", "curry powder"])
        #expect(store.loadItems().count == 2)
    }
}
