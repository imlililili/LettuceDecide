import Foundation
import Testing
@testable import LettuceDecide

@MainActor
struct WeeklyPlannerViewModelTests {
    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    /// 2023-11-16 is a Thursday; the week's Monday is 2023-11-13.
    private let thursday = Date(timeIntervalSince1970: 1_700_092_800)
    private let expectedMonday = Date(timeIntervalSince1970: 1_699_833_600)

    private func makeViewModel(
        pantry: [PantryIngredient] = [
            PantryIngredient(ingredientName: "onion", quantity: 3, unit: .pieces, storageLocation: .pantry)
        ],
        candidates: [PantryRecipeCandidate] = (1...7).map {
            PantryRecipeCandidate(
                recipe: Recipe(id: $0, title: "Recipe \($0)", readyInMinutes: 30),
                usedIngredientNames: ["onion"],
                missedIngredients: []
            )
        },
        repositoryError: Error? = nil
    ) -> (WeeklyPlannerViewModel, InMemoryScheduleStore) {
        let scheduleStore = InMemoryScheduleStore()
        let pantryStore = InMemoryPantryStore(initial: pantry)
        let viewModel = WeeklyPlannerViewModel(
            recordBusyness: RecordBusynessUseCase(store: scheduleStore),
            generatePlan: GenerateWeeklyMealPlanUseCase(
                recipeRepository: MockRecipeRepository(candidates: candidates, errorToThrow: repositoryError),
                pantryStore: pantryStore,
                preferencesStore: InMemoryUserPreferencesStore()
            ),
            pantryStore: pantryStore,
            now: thursday,
            calendar: utc
        )
        return (viewModel, scheduleStore)
    }

    @Test func startsEditingWithSevenNormalDaysFromMonday() {
        let (viewModel, _) = makeViewModel()

        #expect(viewModel.state == .editing)
        #expect(viewModel.days.count == 7)
        #expect(viewModel.days.allSatisfy { $0.busyness == .normal })
        #expect(viewModel.days.first?.date == expectedMonday)
        #expect(viewModel.days.map(\.date) == (0..<7).map {
            expectedMonday.addingTimeInterval(Double($0) * 86_400)
        })
    }

    @Test func generateProducesAPlanAndRecordsEveryDaysBusyness() async {
        let (viewModel, scheduleStore) = makeViewModel()
        viewModel.days[0].busyness = .busy

        await viewModel.generate()

        guard case .generated(let plan) = viewModel.state else {
            Issue.record("expected .generated, got \(viewModel.state)")
            return
        }
        #expect(plan.days.count == 7)
        #expect(scheduleStore.loadEntries().count == 7)
        #expect(scheduleStore.loadEntries().first?.busyness == .busy)
    }

    @Test func generateFailsGracefullyWhenThePantryIsEmpty() async {
        let (viewModel, _) = makeViewModel(pantry: [])

        await viewModel.generate()

        guard case .failed(let message) = viewModel.state else {
            Issue.record("expected .failed, got \(viewModel.state)")
            return
        }
        #expect(!message.isEmpty)
    }

    @Test func backToEditingClearsAFailure() async {
        let (viewModel, _) = makeViewModel(repositoryError: RecipeRepositoryError.noResultsFound)

        await viewModel.generate()
        viewModel.backToEditing()

        #expect(viewModel.state == .editing)
    }
}

struct PantryMatchResultMatchingTests {
    private let recipe = Recipe(
        id: 1,
        title: "Chickpea stew",
        requiredIngredients: [
            RecipeIngredient(id: 1, name: "chickpeas", requiredQuantity: 400, unit: .grams),
            RecipeIngredient(id: 2, name: "curry powder", requiredQuantity: 1, unit: .tablespoons),
        ]
    )

    @Test func splitsRequiredIngredientsIntoHaveAndMissingByName() {
        let pantry = [
            PantryIngredient(ingredientName: "Chickpeas", quantity: 200, unit: .grams, storageLocation: .pantry)
        ]

        let result = PantryMatchResult.matching(recipe, against: pantry)

        #expect(result.matchedIngredients.map(\.ingredientName) == ["Chickpeas"])
        #expect(result.missingIngredients.map(\.name) == ["curry powder"])
    }

    @Test func flagsExpiringMatchedIngredients() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let pantry = [
            PantryIngredient(
                ingredientName: "chickpeas",
                quantity: 400,
                unit: .grams,
                storageLocation: .pantry,
                expiryDate: now.addingTimeInterval(86_400)
            )
        ]

        let result = PantryMatchResult.matching(recipe, against: pantry, now: now)

        #expect(result.usesExpiringIngredients)
    }
}
