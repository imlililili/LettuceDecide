import Foundation
import Testing
@testable import LettuceDecide

struct ConfirmPlannedMealUseCaseTests {
    private let monday = Date(timeIntervalSince1970: 1_699_833_600) // a Monday, UTC midnight
    private var tuesday: Date { monday.addingTimeInterval(86_400) }

    private func recipe(_ id: Int, ingredients: [RecipeIngredient] = []) -> Recipe {
        Recipe(id: id, title: "Recipe \(id)", requiredIngredients: ingredients)
    }

    private func ingredient(_ id: Int, _ name: String, _ qty: Double, _ unit: IngredientUnit) -> RecipeIngredient {
        RecipeIngredient(id: id, name: name, requiredQuantity: qty, unit: unit)
    }

    private func makeUseCase(
        pantry: [PantryIngredient] = [],
        confirmedMeals: [ConfirmedMeal] = []
    ) -> (ConfirmPlannedMealUseCase, InMemoryConfirmedMealStore, InMemoryShoppingListStore, InMemoryPantryStore) {
        let confirmedMealStore = InMemoryConfirmedMealStore(initial: confirmedMeals)
        let shoppingListStore = InMemoryShoppingListStore()
        let pantryStore = InMemoryPantryStore(initial: pantry)
        let useCase = ConfirmPlannedMealUseCase(
            confirmedMealStore: confirmedMealStore,
            pantryStore: pantryStore,
            addToShoppingList: AddMissingIngredientsToShoppingListUseCase(store: shoppingListStore)
        )
        return (useCase, confirmedMealStore, shoppingListStore, pantryStore)
    }

    @Test func recordsTheConfirmedMeal() {
        let (useCase, confirmedMealStore, _, _) = makeUseCase()

        useCase.execute(recipe: recipe(1), date: monday, calendar: .current, now: monday)

        #expect(confirmedMealStore.loadConfirmedMeals().map(\.recipe.id) == [1])
    }

    @Test func neverTouchesTheRealPantry() {
        let (useCase, _, _, pantryStore) = makeUseCase(
            pantry: [PantryIngredient(ingredientName: "chickpeas", quantity: 400, unit: .grams, storageLocation: .pantry)]
        )

        useCase.execute(
            recipe: recipe(1, ingredients: [ingredient(1, "chickpeas", 400, .grams)]),
            date: monday,
            calendar: .current,
            now: monday
        )

        #expect(pantryStore.load().first?.quantity == 400)
    }

    @Test func addsOnlyTheNetShortfallToTheShoppingList() {
        let (useCase, _, shoppingListStore, _) = makeUseCase(
            pantry: [PantryIngredient(ingredientName: "chickpeas", quantity: 100, unit: .grams, storageLocation: .pantry)]
        )

        useCase.execute(
            recipe: recipe(1, ingredients: [
                ingredient(1, "chickpeas", 400, .grams),
                ingredient(2, "spinach", 200, .grams),
            ]),
            date: monday,
            calendar: .current,
            now: monday
        )

        let list = shoppingListStore.loadItems()
        #expect(list.first { $0.ingredientName == "chickpeas" }?.requiredQuantity == 300) // 400 - 100 on hand
        #expect(list.first { $0.ingredientName == "spinach" }?.requiredQuantity == 200) // none on hand
    }

    @Test func addsNothingWhenThePantryAlreadyCoversTheRecipe() {
        let (useCase, _, shoppingListStore, _) = makeUseCase(
            pantry: [PantryIngredient(ingredientName: "chickpeas", quantity: 400, unit: .grams, storageLocation: .pantry)]
        )

        useCase.execute(
            recipe: recipe(1, ingredients: [ingredient(1, "chickpeas", 400, .grams)]),
            date: monday,
            calendar: .current,
            now: monday
        )

        #expect(shoppingListStore.loadItems().isEmpty)
    }

    /// The scenario the user flagged as the easiest thing to get wrong: two different
    /// confirmed days sharing an ingredient must not each be offered the same physical stock.
    @Test func nettingASecondConfirmedDayAccountsForWhatTheFirstDayAlreadyClaimed() {
        let mondayRecipe = recipe(1, ingredients: [ingredient(1, "chickpeas", 300, .grams)])
        let tuesdayRecipe = recipe(2, ingredients: [ingredient(1, "chickpeas", 300, .grams)])
        let (useCase, _, shoppingListStore, _) = makeUseCase(
            pantry: [PantryIngredient(ingredientName: "chickpeas", quantity: 400, unit: .grams, storageLocation: .pantry)]
        )

        useCase.execute(recipe: mondayRecipe, date: monday, calendar: .current, now: monday)
        // Monday used 300 of 400 → nothing bought for Monday. Tuesday needs 300 but only 100
        // of the real pantry is left unclaimed → buy 200, not 0 (which double-counts) and not
        // 300 (which ignores the pantry entirely).
        useCase.execute(recipe: tuesdayRecipe, date: tuesday, calendar: .current, now: tuesday)

        let chickpeas = shoppingListStore.loadItems().first { $0.ingredientName == "chickpeas" }
        #expect(chickpeas?.requiredQuantity == 200)
    }

    /// The exact scenario from the user's bug report: confirming two *different* days, each
    /// independently, whose recipes both need the same ingredient. This is the real
    /// regression this branch fixes — a prior test only ever checked merging *within* one
    /// call's items; the actual bug was that a second, separate `execute` call for a later
    /// day never found (and combined with) what an earlier call had already persisted.
    @Test func confirmingTwoDifferentDaysWithTheSameIngredientMergesAcrossTheTwoCalls() {
        let (useCase, _, shoppingListStore, _) = makeUseCase()

        useCase.execute(
            recipe: recipe(1, ingredients: [ingredient(9152, "lemon juice", 1, .tablespoons)]),
            date: monday, calendar: .current, now: monday
        )
        useCase.execute(
            recipe: recipe(2, ingredients: [ingredient(9152, "lemon juice", 1, .tablespoons)]),
            date: tuesday, calendar: .current, now: tuesday
        )

        let lemonJuiceLines = shoppingListStore.loadItems().filter { $0.ingredientName == "lemon juice" }
        #expect(lemonJuiceLines.count == 1)
        #expect(lemonJuiceLines.first?.requiredQuantity == 2)
    }

    /// Same scenario, but the two recipes' ingredient lines carry the identical display name
    /// with *different* Spoonacular ids — live-diagnosed as a real thing Spoonacular's own
    /// data does (e.g. "olive oil" tagged 4053 in most recipes, 1034053 for an "extra virgin"
    /// variant). Matching by id alone would leave these on two lines forever; the fix matches
    /// on name too.
    @Test func confirmingTwoDifferentDaysWhoseIngredientsShareANameButNotAnIdStillMergesAcrossCalls() {
        let (useCase, _, shoppingListStore, _) = makeUseCase()

        useCase.execute(
            recipe: recipe(1, ingredients: [ingredient(4053, "olive oil", 2, .tablespoons)]),
            date: monday, calendar: .current, now: monday
        )
        useCase.execute(
            recipe: recipe(2, ingredients: [ingredient(1_034_053, "olive oil", 1, .tablespoons)]),
            date: tuesday, calendar: .current, now: tuesday
        )

        let oliveOilLines = shoppingListStore.loadItems().filter { $0.ingredientName == "olive oil" }
        #expect(oliveOilLines.count == 1)
        #expect(oliveOilLines.first?.requiredQuantity == 3)
    }

    /// Same regression, against the real file-backed store, with a *fresh* store instance per
    /// call (simulating two different app launches, or two different view instantiations,
    /// pointing at the same on-disk file) — directly answering the user's suspicion that this
    /// might be a storage-layer bug rather than a merge-logic one. It reads/writes the same
    /// file both times, so it must merge exactly like the in-memory case above.
    @Test func confirmingTwoDaysWithFreshFileBackedStoreInstancesStillMergesAcrossCalls() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("confirm-cross-call-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("shopping-list.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let confirmedMealStore = InMemoryConfirmedMealStore()
        let pantryStore = InMemoryPantryStore()

        ConfirmPlannedMealUseCase(
            confirmedMealStore: confirmedMealStore,
            pantryStore: pantryStore,
            addToShoppingList: AddMissingIngredientsToShoppingListUseCase(store: ShoppingListStore(fileURL: url))
        ).execute(
            recipe: recipe(1, ingredients: [ingredient(9152, "lemon juice", 1, .tablespoons)]),
            date: monday, calendar: .current, now: monday
        )

        ConfirmPlannedMealUseCase(
            confirmedMealStore: confirmedMealStore,
            pantryStore: pantryStore,
            addToShoppingList: AddMissingIngredientsToShoppingListUseCase(store: ShoppingListStore(fileURL: url))
        ).execute(
            recipe: recipe(2, ingredients: [ingredient(9152, "lemon juice", 1, .tablespoons)]),
            date: tuesday, calendar: .current, now: tuesday
        )

        let finalItems = ShoppingListStore(fileURL: url).loadItems()
        #expect(finalItems.count == 1)
        #expect(finalItems.first?.requiredQuantity == 2)
    }

    @Test func reconfirmingTheSameDayWithADifferentRecipeReplacesTheConfirmedMeal() {
        let (useCase, confirmedMealStore, _, _) = makeUseCase(confirmedMeals: [
            ConfirmedMeal(date: monday, recipe: recipe(1))
        ])

        useCase.execute(recipe: recipe(2), date: monday, calendar: .current, now: monday)

        let all = confirmedMealStore.loadConfirmedMeals()
        #expect(all.count == 1)
        #expect(all.first?.recipe.id == 2)
    }

    @Test func doesNotDoubleCountTheDayBeingReconfirmedAgainstItself() {
        // Re-confirming Monday with the same recipe must not treat "Monday" as an *other*
        // already-confirmed day and subtract its own ingredients from the pantry twice.
        let mondayRecipe = recipe(1, ingredients: [ingredient(1, "chickpeas", 300, .grams)])
        let (useCase, _, shoppingListStore, _) = makeUseCase(
            pantry: [PantryIngredient(ingredientName: "chickpeas", quantity: 300, unit: .grams, storageLocation: .pantry)],
            confirmedMeals: [ConfirmedMeal(date: monday, recipe: mondayRecipe)]
        )

        useCase.execute(recipe: mondayRecipe, date: monday, calendar: .current, now: monday)

        #expect(shoppingListStore.loadItems().isEmpty) // 300 on hand fully covers it, once
    }
}
