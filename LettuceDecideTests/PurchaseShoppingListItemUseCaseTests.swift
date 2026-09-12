import Foundation
import Testing
@testable import LettuceDecide

struct PurchaseShoppingListItemUseCaseTests {
    private func makeUseCase(
        shoppingList: [ShoppingListItem] = [],
        pantry: [PantryIngredient] = []
    ) -> (PurchaseShoppingListItemUseCase, InMemoryShoppingListStore, InMemoryPantryStore) {
        let shoppingListStore = InMemoryShoppingListStore(initial: shoppingList)
        let pantryStore = InMemoryPantryStore(initial: pantry)
        let useCase = PurchaseShoppingListItemUseCase(shoppingListStore: shoppingListStore, pantryStore: pantryStore)
        return (useCase, shoppingListStore, pantryStore)
    }

    @Test func removesTheItemFromTheShoppingListAndAddsItToThePantry() throws {
        let item = ShoppingListItem(ingredientName: "flour", requiredQuantity: 500, unit: .grams, ingredientId: 20081)
        let (useCase, shoppingListStore, pantryStore) = makeUseCase(shoppingList: [item])

        try useCase.execute(item)

        #expect(shoppingListStore.loadItems().isEmpty)
        let pantryLine = try #require(pantryStore.load().first)
        #expect(pantryLine.ingredientName == "flour")
        #expect(pantryLine.quantity == 500)
        #expect(pantryLine.unit == .grams)
        #expect(pantryLine.ingredientId == 20081) // id carried across from the shopping list
    }

    @Test func accumulatesOntoAnExistingMatchingPantryLineRatherThanOverwriting() throws {
        let existing = PantryIngredient(
            ingredientName: "onion", quantity: 200, unit: .grams, storageLocation: .fridge, ingredientId: 11282
        )
        let item = ShoppingListItem(ingredientName: "onion", requiredQuantity: 300, unit: .grams, ingredientId: 11282)
        let (useCase, _, pantryStore) = makeUseCase(shoppingList: [item], pantry: [existing])

        try useCase.execute(item, storageLocation: .fridge)

        let pantry = pantryStore.load()
        #expect(pantry.count == 1)
        #expect(pantry.first?.quantity == 500) // 200 already there + 300 just bought
    }

    @Test func addsANewLineRatherThanConvertingUnits_whenThePantryHasTheSameIngredientInADifferentUnit() throws {
        let existing = PantryIngredient(ingredientName: "onion", quantity: 500, unit: .grams, storageLocation: .fridge)
        let item = ShoppingListItem(ingredientName: "onion", requiredQuantity: 2, unit: .pieces)
        let (useCase, _, pantryStore) = makeUseCase(shoppingList: [item], pantry: [existing])

        try useCase.execute(item, storageLocation: .fridge)

        let pantry = pantryStore.load()
        #expect(pantry.count == 2) // never guesses a gram <-> piece conversion
        #expect(Set(pantry.map(\.unit)) == [.grams, .pieces])
    }

    /// The user's explicit new rule: a volume-class purchase always lands in the pantry as
    /// millilitres, unconditionally — not only once it collides with an existing millilitres
    /// line. cups/tablespoons/teaspoons are too imprecise to track long-term inventory in.
    @Test func buyingAVolumeItemStoresItAsMillilitresEvenWithNoExistingPantryLine() throws {
        let item = ShoppingListItem(ingredientName: "olive oil", requiredQuantity: 2, unit: .cups, ingredientId: 4053)
        let (useCase, _, pantryStore) = makeUseCase(shoppingList: [item])

        try useCase.execute(item)

        let pantryLine = try #require(pantryStore.load().first)
        #expect(pantryLine.unit == .millilitres)
        #expect(pantryLine.quantity == 480) // 2 cups -> 480ml
    }

    @Test func buyingAVolumeItemMergesWithAnExistingMillilitresLineAfterNormalising() throws {
        let existing = PantryIngredient(
            ingredientName: "olive oil", quantity: 100, unit: .millilitres, storageLocation: .fridge, ingredientId: 4053
        )
        let item = ShoppingListItem(ingredientName: "olive oil", requiredQuantity: 1, unit: .tablespoons, ingredientId: 4053)
        let (useCase, _, pantryStore) = makeUseCase(shoppingList: [item], pantry: [existing])

        try useCase.execute(item, storageLocation: .fridge)

        let pantry = pantryStore.load()
        #expect(pantry.count == 1)
        #expect(pantry.first?.quantity == 115) // 100ml already there + 15ml (1 tbsp)
    }

    @Test func doesNotRemoveFromTheShoppingListWhenThePantryWriteFails() {
        // Confirming with an explicit zero quantity fails ManagePantryIngredientUseCase's own
        // validation — the item must stay on the list rather than vanish with nothing to show
        // for it.
        let item = ShoppingListItem(ingredientName: "flour", requiredQuantity: 500, unit: .grams)
        let (useCase, shoppingListStore, pantryStore) = makeUseCase(shoppingList: [item])

        #expect(throws: PantryIngredientError.self) {
            try useCase.execute(item, confirmedQuantity: 0, confirmedUnit: .grams)
        }

        #expect(shoppingListStore.loadItems().map(\.id) == [item.id])
        #expect(pantryStore.load().isEmpty)
    }

    // MARK: - Uncertain quantities

    @Test func requiresAConfirmedAmountForAnUncertainQuantityItem() {
        let item = ShoppingListItem(
            ingredientName: "green onions", requiredQuantity: 4, unit: .pieces, quantityIsUncertain: true
        )
        let (useCase, shoppingListStore, pantryStore) = makeUseCase(shoppingList: [item])

        #expect(throws: PurchaseShoppingListItemError.quantityConfirmationRequired(ingredientName: "green onions")) {
            try useCase.execute(item)
        }

        // Neither side effect happened — the item is exactly where the cook left it.
        #expect(shoppingListStore.loadItems().map(\.id) == [item.id])
        #expect(pantryStore.load().isEmpty)
    }

    @Test func usesTheConfirmedAmountInsteadOfTheUntrustworthyOriginalQuantity() throws {
        let item = ShoppingListItem(
            ingredientName: "green onions", requiredQuantity: 4, unit: .pieces, quantityIsUncertain: true
        )
        let (useCase, shoppingListStore, pantryStore) = makeUseCase(shoppingList: [item])

        try useCase.execute(item, confirmedQuantity: 6, confirmedUnit: .pieces)

        #expect(shoppingListStore.loadItems().isEmpty)
        let pantryLine = try #require(pantryStore.load().first)
        #expect(pantryLine.quantity == 6) // the cook's real number, not the uncertain "4"
        #expect(pantryLine.unit == .pieces)
    }
}
