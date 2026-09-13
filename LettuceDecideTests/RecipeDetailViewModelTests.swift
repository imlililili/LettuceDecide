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
        confirmedMealStore: InMemoryConfirmedMealStore = InMemoryConfirmedMealStore(),
        context: RecipeDetailContext = .confirmed(date: Date(timeIntervalSince1970: 1_700_000_000)),
        now: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> RecipeDetailViewModel {
        RecipeDetailViewModel(
            recipe: recipe,
            pantryStore: pantryStore,
            addToShoppingList: AddMissingIngredientsToShoppingListUseCase(store: shoppingListStore),
            confirmedMealStore: confirmedMealStore,
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

    /// The checklist must convert within a measurement group too, not only exact-unit-match:
    /// the pantry stores olive oil in millilitres (post-normalisation) while the recipe still
    /// calls for tablespoons — this should read as an honest "short by" amount, not a
    /// false-positive "have" (the old exact-match rule silently fell through to `.have`
    /// whenever units differed at all, hiding a real shortfall).
    @Test func ingredientStatusesConvertWithinAMeasurementGroupInsteadOfFalsePositiveHave() throws {
        let cooked = recipe([
            RecipeIngredient(id: 1, name: "olive oil", requiredQuantity: 2, unit: .tablespoons)
        ])
        let store = InMemoryPantryStore(initial: [
            PantryIngredient(ingredientName: "olive oil", quantity: 10, unit: .millilitres, storageLocation: .pantry)
        ])
        let viewModel = makeViewModel(cooked, pantryStore: store)

        // 2 tbsp needed = 30ml; only 10ml on hand = 10/15 = 0.667 tbsp worth.
        let statuses = viewModel.ingredientStatuses
        #expect(statuses.count == 1)
        guard case .shortBy(let have, let unit) = statuses.first?.kind else {
            Issue.record("expected .shortBy, got \(String(describing: statuses.first?.kind))")
            return
        }
        #expect(unit == .tablespoons)
        #expect(abs(have - (10.0 / 15.0)) < 0.0001)
    }

    @Test func ingredientStatusesStillFallBackToHaveAcrossUnconvertibleMeasurementGroups() {
        let cooked = recipe([
            RecipeIngredient(id: 1, name: "flour", requiredQuantity: 300, unit: .grams)
        ])
        let store = InMemoryPantryStore(initial: [
            PantryIngredient(ingredientName: "flour", quantity: 2, unit: .cups, storageLocation: .pantry)
        ])
        let viewModel = makeViewModel(cooked, pantryStore: store)

        // Weight vs volume can't be compared -- same conservative fallback as before.
        #expect(viewModel.ingredientStatuses.map(\.kind) == [.have])
    }

    // MARK: - .confirmed: Mark as Cooked deducts once the day has arrived

    @Test func fromConfirmed_markAsCookedDeductsAndReportsSuccess() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let store = InMemoryPantryStore(initial: [
            PantryIngredient(ingredientName: "flour", quantity: 500, unit: .grams, storageLocation: .pantry)
        ])
        let viewModel = makeViewModel(
            recipe([RecipeIngredient(id: 1, name: "flour", requiredQuantity: 200, unit: .grams)]),
            pantryStore: store,
            context: .confirmed(date: now),
            now: now
        )

        #expect(viewModel.canMarkAsCooked)
        viewModel.markAsCooked()

        #expect(viewModel.notice?.dismissPops == true)
        #expect(store.load().first?.quantity == 300)
    }

    @Test func fromConfirmed_markAsCookedSurfacesInsufficientQuantityWithoutSaving() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let store = InMemoryPantryStore(initial: [
            PantryIngredient(ingredientName: "flour", quantity: 100, unit: .grams, storageLocation: .pantry)
        ])
        let viewModel = makeViewModel(
            recipe([RecipeIngredient(id: 1, name: "flour", requiredQuantity: 250, unit: .grams)]),
            pantryStore: store,
            context: .confirmed(date: now),
            now: now
        )

        viewModel.markAsCooked()

        #expect(viewModel.notice?.dismissPops == false)
        #expect(store.load().first?.quantity == 100)
    }

    @Test func fromConfirmed_aFutureDayCannotBeMarkedCooked() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let futureDay = now.addingTimeInterval(3 * 86_400)
        let viewModel = makeViewModel(
            recipe([RecipeIngredient(id: 1, name: "flour", requiredQuantity: 200, unit: .grams)]),
            pantryStore: InMemoryPantryStore(),
            context: .confirmed(date: futureDay),
            now: now
        )

        #expect(!viewModel.canMarkAsCooked)
    }

    @Test func fromConfirmed_aPastDayCanStillBeMarkedCooked() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let yesterday = now.addingTimeInterval(-86_400)
        let viewModel = makeViewModel(
            recipe([RecipeIngredient(id: 1, name: "flour", requiredQuantity: 200, unit: .grams)]),
            pantryStore: InMemoryPantryStore(),
            context: .confirmed(date: yesterday),
            now: now
        )

        #expect(viewModel.canMarkAsCooked)
    }

    /// There's no "confirm" action once a meal is already confirmed — `.confirmed` has no UI
    /// path to `confirmPlannedMeal()`, but the guard itself must still hold if it's ever
    /// called, exactly like `.weekPlan`'s own guard against a mismatched context.
    @Test func fromConfirmed_confirmPlannedMealIsANoOp() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let confirmedMealStore = InMemoryConfirmedMealStore()
        let viewModel = makeViewModel(
            recipe([RecipeIngredient(id: 1, name: "flour", requiredQuantity: 200, unit: .grams)]),
            pantryStore: InMemoryPantryStore(),
            confirmedMealStore: confirmedMealStore,
            context: .confirmed(date: now),
            now: now
        )

        viewModel.confirmPlannedMeal()

        #expect(!viewModel.isConfirmedForPlan)
        #expect(confirmedMealStore.loadConfirmedMeals().isEmpty)
        #expect(viewModel.notice == nil)
    }

    // MARK: - Mark as Cooked always drops the confirmed-meal record for that day

    @Test func fromConfirmed_markAsCookedRemovesTheConfirmedMealOnSuccess() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let curry = recipe([RecipeIngredient(id: 1, name: "flour", requiredQuantity: 200, unit: .grams)])
        let confirmedMealStore = InMemoryConfirmedMealStore(initial: [
            ConfirmedMeal(date: now, recipe: curry, confirmedAt: now)
        ])
        let viewModel = makeViewModel(
            curry,
            pantryStore: InMemoryPantryStore(initial: [
                PantryIngredient(ingredientName: "flour", quantity: 500, unit: .grams, storageLocation: .pantry)
            ]),
            confirmedMealStore: confirmedMealStore,
            context: .confirmed(date: now),
            now: now
        )

        viewModel.markAsCooked()

        #expect(viewModel.notice?.dismissPops == true)
        #expect(confirmedMealStore.loadConfirmedMeals().isEmpty)
    }

    /// The easiest edge case to miss: a same-measurement-group mismatch lands in
    /// `needsManualReview` (the recipe olive-oil bug), which is still a *successful*
    /// `execute()` call — nothing thrown — so this was already covered by the success path
    /// above. What isn't obvious is that a genuine thrown error must not block removal either:
    /// the cook already ate the meal regardless of whether the pantry bookkeeping that follows
    /// goes smoothly.
    @Test func fromConfirmed_markAsCookedRemovesTheConfirmedMealEvenWhenDeductionNeedsManualReview() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let curry = recipe([RecipeIngredient(id: 1, name: "olive oil", requiredQuantity: 2, unit: .tablespoons)])
        let confirmedMealStore = InMemoryConfirmedMealStore(initial: [
            ConfirmedMeal(date: now, recipe: curry, confirmedAt: now)
        ])
        let viewModel = makeViewModel(
            curry,
            pantryStore: InMemoryPantryStore(initial: [
                // Genuinely cross-group (pieces, not a volume unit) — can't be converted, so
                // this recipe's olive oil is reported in `needsManualReview`, not deducted.
                PantryIngredient(ingredientName: "olive oil", quantity: 1, unit: .pieces, storageLocation: .pantry)
            ]),
            confirmedMealStore: confirmedMealStore,
            context: .confirmed(date: now),
            now: now
        )

        viewModel.markAsCooked()

        #expect(viewModel.notice?.dismissPops == true) // still a successful call, just flagged
        #expect(confirmedMealStore.loadConfirmedMeals().isEmpty)
    }

    @Test func fromConfirmed_markAsCookedRemovesTheConfirmedMealEvenWhenTheDeductionThrows() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let curry = recipe([RecipeIngredient(id: 1, name: "flour", requiredQuantity: 250, unit: .grams)])
        let confirmedMealStore = InMemoryConfirmedMealStore(initial: [
            ConfirmedMeal(date: now, recipe: curry, confirmedAt: now)
        ])
        let viewModel = makeViewModel(
            curry,
            pantryStore: InMemoryPantryStore(initial: [
                PantryIngredient(ingredientName: "flour", quantity: 100, unit: .grams, storageLocation: .pantry)
            ]),
            confirmedMealStore: confirmedMealStore,
            context: .confirmed(date: now),
            now: now
        )

        viewModel.markAsCooked()

        // The pantry error notice stays up (dismissPops false, same as before this fix) — only
        // the confirmed-meal bookkeeping changed.
        #expect(viewModel.notice?.dismissPops == false)
        #expect(confirmedMealStore.loadConfirmedMeals().isEmpty)
    }

    /// `.weekPlan` shares the exact same "Mark as Cooked" button and date-gating rule as
    /// `.confirmed` (see `canMarkAsCooked`'s doc comment) — a day can be marked cooked straight
    /// from the Week Plan preview without ever having been confirmed first, so the same
    /// unconditional removal applies there too (a no-op when nothing was confirmed for that
    /// day, same as `ConfirmedMealStoring.removeConfirmedMeal` documents).
    @Test func fromWeekPlan_markAsCookedRemovesAnyConfirmedMealForThatDayToo() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let today = Calendar.current.startOfDay(for: now)
        let curry = recipe([RecipeIngredient(id: 1, name: "flour", requiredQuantity: 200, unit: .grams)])
        let confirmedMealStore = InMemoryConfirmedMealStore(initial: [
            ConfirmedMeal(date: today, recipe: curry, confirmedAt: now)
        ])
        let viewModel = makeViewModel(
            curry,
            pantryStore: InMemoryPantryStore(initial: [
                PantryIngredient(ingredientName: "flour", quantity: 500, unit: .grams, storageLocation: .pantry)
            ]),
            confirmedMealStore: confirmedMealStore,
            context: .weekPlan(date: today),
            now: now
        )

        viewModel.markAsCooked()

        #expect(confirmedMealStore.loadConfirmedMeals().isEmpty)
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

    @Test func fromWeekPlan_confirmingDurablyRecordsTheConfirmedMealAndItsShortfall() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let futureDay = now.addingTimeInterval(3 * 86_400)
        let confirmedMealStore = InMemoryConfirmedMealStore()
        let shoppingListStore = InMemoryShoppingListStore()
        let curry = recipe([
            RecipeIngredient(id: 1, name: "flour", requiredQuantity: 200, unit: .grams),
            RecipeIngredient(id: 2, name: "sugar", requiredQuantity: 100, unit: .grams),
        ])
        let viewModel = makeViewModel(
            curry,
            pantryStore: InMemoryPantryStore(initial: [
                PantryIngredient(ingredientName: "flour", quantity: 500, unit: .grams, storageLocation: .pantry)
            ]),
            shoppingListStore: shoppingListStore,
            confirmedMealStore: confirmedMealStore,
            context: .weekPlan(date: futureDay),
            now: now
        )

        viewModel.confirmPlannedMeal()

        #expect(confirmedMealStore.loadConfirmedMeals().map(\.recipe.id) == [curry.id])
        // flour is fully on hand (no shortfall); sugar isn't in the pantry at all.
        #expect(shoppingListStore.loadItems().map(\.ingredientName) == ["sugar"])
    }

    @Test func fromWeekPlan_reopeningAnAlreadyConfirmedDayStartsAsConfirmed() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let futureDay = now.addingTimeInterval(3 * 86_400)
        let curry = recipe([RecipeIngredient(id: 1, name: "flour", requiredQuantity: 200, unit: .grams)])
        let confirmedMealStore = InMemoryConfirmedMealStore(initial: [
            ConfirmedMeal(date: futureDay, recipe: curry, confirmedAt: now)
        ])

        let viewModel = makeViewModel(
            curry,
            pantryStore: InMemoryPantryStore(),
            confirmedMealStore: confirmedMealStore,
            context: .weekPlan(date: futureDay),
            now: now
        )

        #expect(viewModel.isConfirmedForPlan)
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
