import Foundation
import Testing
@testable import LettuceDecide

@MainActor
struct HomeViewModelTests {
    private func makeViewModel(
        shoppingList: [ShoppingListItem] = [],
        pantry: [PantryIngredient] = []
    ) -> (HomeViewModel, InMemoryShoppingListStore, InMemoryPantryStore) {
        let confirmedMealStore = InMemoryConfirmedMealStore()
        let shoppingListStore = InMemoryShoppingListStore(initial: shoppingList)
        let pantryStore = InMemoryPantryStore(initial: pantry)
        let viewModel = HomeViewModel(
            confirmedMealStore: confirmedMealStore,
            shoppingListStore: shoppingListStore,
            pantryStore: pantryStore
        )
        return (viewModel, shoppingListStore, pantryStore)
    }

    @Test func markAsBoughtOnATrustworthyItemRemovesItAndAddsItToThePantryImmediately() {
        let item = ShoppingListItem(ingredientName: "flour", requiredQuantity: 500, unit: .grams, ingredientId: 20081)
        let (viewModel, _, pantryStore) = makeViewModel(shoppingList: [item])

        viewModel.markAsBought(item)

        #expect(viewModel.shoppingList.isEmpty)
        #expect(viewModel.pendingUncertainPurchase == nil)
        #expect(pantryStore.load().first?.ingredientName == "flour")
    }

    @Test func markAsBoughtOnAnUncertainItemOpensTheConfirmSheetWithoutTouchingEitherStore() {
        let item = ShoppingListItem(
            ingredientName: "green onions", requiredQuantity: 4, unit: .pieces, quantityIsUncertain: true
        )
        let (viewModel, shoppingListStore, pantryStore) = makeViewModel(shoppingList: [item])

        viewModel.markAsBought(item)

        #expect(viewModel.pendingUncertainPurchase == item)
        #expect(viewModel.shoppingList.map(\.id) == [item.id]) // still shown, untouched
        #expect(shoppingListStore.loadItems().map(\.id) == [item.id])
        #expect(pantryStore.load().isEmpty)
    }

    @Test func confirmUncertainPurchaseCompletesThePurchaseAndClosesTheSheet() {
        let item = ShoppingListItem(
            ingredientName: "green onions", requiredQuantity: 4, unit: .pieces, quantityIsUncertain: true
        )
        let (viewModel, _, pantryStore) = makeViewModel(shoppingList: [item])
        viewModel.markAsBought(item)

        viewModel.confirmUncertainPurchase(quantity: 6, unit: .pieces)

        #expect(viewModel.pendingUncertainPurchase == nil)
        #expect(viewModel.shoppingList.isEmpty)
        #expect(pantryStore.load().first?.quantity == 6)
    }

    @Test func cancelUncertainPurchaseLeavesTheItemOnTheListUntouched() {
        let item = ShoppingListItem(
            ingredientName: "green onions", requiredQuantity: 4, unit: .pieces, quantityIsUncertain: true
        )
        let (viewModel, shoppingListStore, pantryStore) = makeViewModel(shoppingList: [item])
        viewModel.markAsBought(item)

        viewModel.cancelUncertainPurchase()

        #expect(viewModel.pendingUncertainPurchase == nil)
        #expect(shoppingListStore.loadItems().map(\.id) == [item.id])
        #expect(pantryStore.load().isEmpty)
    }
}
