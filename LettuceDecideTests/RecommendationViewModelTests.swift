import Foundation
import Testing
@testable import LettuceDecide

@MainActor
struct RecommendationViewModelTests {
    private func makeUseCase(
        pantry: [PantryIngredient],
        repository: RecipeRepository = MockRecipeRepository()
    ) -> RecommendMealsFromPantryUseCase {
        RecommendMealsFromPantryUseCase(
            recipeRepository: repository,
            pantryStore: InMemoryPantryStore(initial: pantry),
            preferencesStore: InMemoryUserPreferencesStore()
        )
    }

    @Test func decideTransitionsFromLoadingToLoadedOnSuccess() async {
        let viewModel = RecommendationViewModel(recommendMeals: makeUseCase(
            pantry: [PantryIngredient(ingredientName: "spinach", quantity: 200, unit: .grams, storageLocation: .fridge)]
        ))

        #expect(viewModel.state == .idle)
        await viewModel.decide()

        guard case .loaded(let results) = viewModel.state else {
            Issue.record("Expected .loaded state, got \(viewModel.state)")
            return
        }
        #expect(!results.isEmpty)
    }

    @Test func decideTransitionsToFailedWhenPantryIsEmpty() async {
        let viewModel = RecommendationViewModel(recommendMeals: makeUseCase(pantry: []))

        await viewModel.decide()

        guard case .failed = viewModel.state else {
            Issue.record("Expected .failed state, got \(viewModel.state)")
            return
        }
    }

    @Test func decideTransitionsToFailedOnServiceError() async {
        let repository = MockRecipeRepository(errorToThrow: RecipeRepositoryError.noResultsFound)
        let viewModel = RecommendationViewModel(recommendMeals: makeUseCase(
            pantry: [PantryIngredient(ingredientName: "rice", quantity: 500, unit: .grams, storageLocation: .pantry)],
            repository: repository
        ))

        await viewModel.decide()

        guard case .failed = viewModel.state else {
            Issue.record("Expected .failed state, got \(viewModel.state)")
            return
        }
    }

    // MARK: - Reacting to pantry changes without refetching

    private final class CountingRepository: RecipeRepository {
        let candidates: [PantryRecipeCandidate]
        private(set) var callCount = 0

        init(_ candidates: [PantryRecipeCandidate]) {
            self.candidates = candidates
        }

        func findRecipes(
            usingPantryNames pantryIngredientNames: [String],
            matching preferences: UserPreferences
        ) async throws -> [PantryRecipeCandidate] {
            callCount += 1
            return candidates
        }
    }

    @Test func pantryChangeReRanksLoadedResultsLocallyWithoutRefetching() async {
        let store = InMemoryPantryStore(initial: [
            PantryIngredient(ingredientName: "flour", quantity: 500, unit: .grams, storageLocation: .pantry)
        ])
        let repo = CountingRepository([
            PantryRecipeCandidate(
                recipe: Recipe(id: 1, title: "Cake"),
                usedIngredientNames: ["flour"],
                missedIngredients: [RecipeIngredient(id: 2, name: "sugar", requiredQuantity: 100, unit: .grams)]
            )
        ])
        let viewModel = RecommendationViewModel(recommendMeals: RecommendMealsFromPantryUseCase(
            recipeRepository: repo,
            pantryStore: store,
            preferencesStore: InMemoryUserPreferencesStore()
        ))

        await viewModel.decide()
        guard case .loaded(let before) = viewModel.state else {
            Issue.record("Expected .loaded, got \(viewModel.state)")
            return
        }
        #expect(before.first?.matchPercentage == 0.5)
        #expect(repo.callCount == 1)

        // The cook adds the missing ingredient; no button is pressed.
        store.save(store.load() + [
            PantryIngredient(ingredientName: "sugar", quantity: 500, unit: .grams, storageLocation: .pantry)
        ])

        guard case .loaded(let after) = viewModel.state else {
            Issue.record("Expected .loaded after pantry change, got \(viewModel.state)")
            return
        }
        #expect(after.first?.matchPercentage == 1.0)
        #expect(after.first?.missingIngredients.isEmpty == true)
        #expect(repo.callCount == 1) // never refetched
    }

    @Test func pantryChangeIsIgnoredWhileNoResultsAreLoaded() async {
        // Non-empty pantry, but the service returns nothing safe -> .failed with no pool.
        let store = InMemoryPantryStore(initial: [
            PantryIngredient(ingredientName: "rice", quantity: 500, unit: .grams, storageLocation: .pantry)
        ])
        let repo = CountingRepository([])
        let viewModel = RecommendationViewModel(recommendMeals: RecommendMealsFromPantryUseCase(
            recipeRepository: repo,
            pantryStore: store,
            preferencesStore: InMemoryUserPreferencesStore()
        ))

        await viewModel.decide()
        guard case .failed = viewModel.state else {
            Issue.record("Expected .failed, got \(viewModel.state)")
            return
        }
        #expect(repo.callCount == 1)

        store.save(store.load() + [
            PantryIngredient(ingredientName: "flour", quantity: 100, unit: .grams, storageLocation: .pantry)
        ])

        // A pantry edit must not start any work when there is no pool to re-rank.
        guard case .failed = viewModel.state else {
            Issue.record("State moved off .failed on a pantry edit: \(viewModel.state)")
            return
        }
        #expect(repo.callCount == 1)
    }
}
