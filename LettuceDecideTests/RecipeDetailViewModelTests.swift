import Foundation
import Testing
@testable import LettuceDecide

@MainActor
struct RecipeDetailViewModelTests {
    private func recipe(_ required: [RecipeIngredient]) -> Recipe {
        Recipe(id: 1, title: "Test Dish", requiredIngredients: required)
    }

    private func makeViewModel(
        _ recipe: Recipe,
        pantryStore: InMemoryPantryStore,
        shoppingListStore: InMemoryShoppingListStore = InMemoryShoppingListStore(),
        context: RecipeDetailContext = .decide,
        now: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> RecipeDetailViewModel {
        RecipeDetailViewModel(
            recipe: recipe,
            pantryStore: pantryStore,
            addToShoppingList: AddMissingIngredientsToShoppingListUseCase(store: shoppingListStore),
            context: context,
            now: now
        )
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
        let viewModel = makeViewModel(cooked, pantryStore: store)

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
        let viewModel = makeViewModel(cooked, pantryStore: store)
        #expect(viewModel.ingredientStatuses.map(\.kind) == [.have, .missing])

        // The cook adds the missing ingredient elsewhere; the checklist catches up with no
        // manual reload.
        store.save(store.load() + [
            PantryIngredient(ingredientName: "sugar", quantity: 60, unit: .grams, storageLocation: .pantry)
        ])

        #expect(viewModel.ingredientStatuses.map(\.kind) == [.have, .shortBy(have: 60, unit: .grams)])
    }

    // MARK: - .decide: Mark as Cooked deducts (regression — must survive the .weekPlan work)

    @Test func fromDecide_markAsCookedDeductsAndReportsSuccess() throws {
        let store = InMemoryPantryStore(initial: [
            PantryIngredient(ingredientName: "flour", quantity: 500, unit: .grams, storageLocation: .pantry)
        ])
        let viewModel = makeViewModel(
            recipe([RecipeIngredient(id: 1, name: "flour", requiredQuantity: 200, unit: .grams)]),
            pantryStore: store,
            context: .decide
        )

        #expect(viewModel.canMarkAsCooked)
        viewModel.markAsCooked()

        #expect(viewModel.notice?.dismissPops == true)
        #expect(store.load().first?.quantity == 300)
    }

    @Test func fromDecide_markAsCookedSurfacesInsufficientQuantityWithoutSaving() {
        let store = InMemoryPantryStore(initial: [
            PantryIngredient(ingredientName: "flour", quantity: 100, unit: .grams, storageLocation: .pantry)
        ])
        let viewModel = makeViewModel(
            recipe([RecipeIngredient(id: 1, name: "flour", requiredQuantity: 250, unit: .grams)]),
            pantryStore: store,
            context: .decide
        )

        viewModel.markAsCooked()

        #expect(viewModel.notice?.dismissPops == false)
        #expect(store.load().first?.quantity == 100)
    }

    // MARK: - .weekPlan: confirming never touches the pantry

    @Test func fromWeekPlan_aFutureDayCannotBeMarkedCooked() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let futureDay = now.addingTimeInterval(3 * 86_400)
        let store = InMemoryPantryStore(initial: [
            PantryIngredient(ingredientName: "flour", quantity: 500, unit: .grams, storageLocation: .pantry)
        ])
        let viewModel = makeViewModel(
            recipe([RecipeIngredient(id: 1, name: "flour", requiredQuantity: 200, unit: .grams)]),
            pantryStore: store,
            context: .weekPlan(date: futureDay),
            now: now
        )

        #expect(!viewModel.canMarkAsCooked)
    }

    @Test func fromWeekPlan_confirmingDoesNotDeductFromThePantry() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let futureDay = now.addingTimeInterval(3 * 86_400)
        let store = InMemoryPantryStore(initial: [
            PantryIngredient(ingredientName: "flour", quantity: 500, unit: .grams, storageLocation: .pantry)
        ])
        let viewModel = makeViewModel(
            recipe([RecipeIngredient(id: 1, name: "flour", requiredQuantity: 200, unit: .grams)]),
            pantryStore: store,
            context: .weekPlan(date: futureDay),
            now: now
        )

        viewModel.confirmPlannedMeal()

        #expect(viewModel.isConfirmedForPlan)
        #expect(viewModel.notice?.dismissPops == false)
        // The whole point of the bug fix: confirming a planned day is not cooking it.
        #expect(store.load().first?.quantity == 500)
    }

    @Test func fromWeekPlan_aDayThatHasAlreadyArrivedCanStillBeMarkedCooked() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let today = Calendar.current.startOfDay(for: now)
        let store = InMemoryPantryStore(initial: [
            PantryIngredient(ingredientName: "flour", quantity: 500, unit: .grams, storageLocation: .pantry)
        ])
        let viewModel = makeViewModel(
            recipe([RecipeIngredient(id: 1, name: "flour", requiredQuantity: 200, unit: .grams)]),
            pantryStore: store,
            context: .weekPlan(date: today),
            now: now
        )

        #expect(viewModel.canMarkAsCooked)
        viewModel.markAsCooked()

        #expect(viewModel.notice?.dismissPops == true)
        #expect(store.load().first?.quantity == 300)
    }

    @Test func fromWeekPlan_aPastDayCanStillBeMarkedCooked() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let yesterday = now.addingTimeInterval(-86_400)
        let viewModel = makeViewModel(
            recipe([RecipeIngredient(id: 1, name: "flour", requiredQuantity: 200, unit: .grams)]),
            pantryStore: InMemoryPantryStore(),
            context: .weekPlan(date: yesterday),
            now: now
        )

        #expect(viewModel.canMarkAsCooked)
    }

    // MARK: - Shopping list

    @Test func addMissingToShoppingListSendsOnlyTheStillMissingIngredients() {
        let cooked = recipe([
            RecipeIngredient(id: 1, name: "flour", requiredQuantity: 200, unit: .grams),
            RecipeIngredient(id: 2, name: "sugar", requiredQuantity: 100, unit: .grams),
        ])
        let shoppingListStore = InMemoryShoppingListStore()
        let viewModel = makeViewModel(
            cooked,
            pantryStore: InMemoryPantryStore(initial: [
                PantryIngredient(ingredientName: "flour", quantity: 500, unit: .grams, storageLocation: .pantry)
            ]),
            shoppingListStore: shoppingListStore
        )

        viewModel.addMissingToShoppingList()

        #expect(shoppingListStore.loadItems().map(\.ingredientName) == ["sugar"])
        #expect(viewModel.notice?.dismissPops == false)
    }
}
