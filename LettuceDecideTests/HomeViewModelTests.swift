import Foundation
import Testing
@testable import LettuceDecide

@MainActor
struct HomeViewModelTests {
    private func makeViewModel(
        confirmedMeals: [ConfirmedMeal] = [],
        shoppingList: [ShoppingListItem] = [],
        pantry: [PantryIngredient] = []
    ) -> (HomeViewModel, InMemoryConfirmedMealStore, InMemoryShoppingListStore, InMemoryPantryStore) {
        let confirmedMealStore = InMemoryConfirmedMealStore(initial: confirmedMeals)
        let shoppingListStore = InMemoryShoppingListStore(initial: shoppingList)
        let pantryStore = InMemoryPantryStore(initial: pantry)
        let viewModel = HomeViewModel(
            confirmedMealStore: confirmedMealStore,
            shoppingListStore: shoppingListStore,
            pantryStore: pantryStore
        )
        return (viewModel, confirmedMealStore, shoppingListStore, pantryStore)
    }

    @Test func markAsBoughtOnATrustworthyItemRemovesItAndAddsItToThePantryImmediately() {
        let item = ShoppingListItem(ingredientName: "flour", requiredQuantity: 500, unit: .grams, ingredientId: 20081)
        let (viewModel, _, _, pantryStore) = makeViewModel(shoppingList: [item])

        viewModel.markAsBought(item)

        #expect(viewModel.shoppingList.isEmpty)
        #expect(viewModel.pendingUncertainPurchase == nil)
        #expect(pantryStore.load().first?.ingredientName == "flour")
    }

    @Test func markAsBoughtOnAnUncertainItemOpensTheConfirmSheetWithoutTouchingEitherStore() {
        let item = ShoppingListItem(
            ingredientName: "green onions", requiredQuantity: 4, unit: .pieces, quantityIsUncertain: true
        )
        let (viewModel, _, shoppingListStore, pantryStore) = makeViewModel(shoppingList: [item])

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
        let (viewModel, _, _, pantryStore) = makeViewModel(shoppingList: [item])
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
        let (viewModel, _, shoppingListStore, pantryStore) = makeViewModel(shoppingList: [item])
        viewModel.markAsBought(item)

        viewModel.cancelUncertainPurchase()

        #expect(viewModel.pendingUncertainPurchase == nil)
        #expect(shoppingListStore.loadItems().map(\.id) == [item.id])
        #expect(pantryStore.load().isEmpty)
    }

    // MARK: - Reacting to a confirmed meal being removed from elsewhere

    /// `RecipeDetailViewModel.markAsCooked()` removes the confirmed meal directly through
    /// `ConfirmedMealStoring`, not through `HomeViewModel` — this is what proves Home actually
    /// picks that up via the `changes` subscription, with no `reload()` call of its own in the
    /// way (see `fix/home-remove-cooked-meal`).
    @Test func confirmedMealsUpdateAutomaticallyWhenTheStoreAnnouncesARemoval() {
        let monday = Date(timeIntervalSince1970: 1_700_000_000)
        let curry = Recipe(id: 1, title: "Curry")
        let (viewModel, confirmedMealStore, _, _) = makeViewModel(
            confirmedMeals: [ConfirmedMeal(date: monday, recipe: curry, confirmedAt: monday)]
        )
        #expect(viewModel.confirmedMeals.map(\.recipe.id) == [1])

        // Not `viewModel.reload()` — the store's own removal, exactly as markAsCooked() does it.
        confirmedMealStore.removeConfirmedMeal(for: monday)

        #expect(viewModel.confirmedMeals.isEmpty)
    }
}
