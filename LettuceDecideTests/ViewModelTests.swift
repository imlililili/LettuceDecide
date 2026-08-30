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

        guard case .loaded = viewModel.state else {
            Issue.record("Expected .loaded state, got \(viewModel.state)")
            return
        }
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
}

@MainActor
struct SettingsViewModelTests {
    @Test func toggleAddsAndRemovesRestrictions() {
        let viewModel = SettingsViewModel(store: InMemoryUserPreferencesStore())

        #expect(!viewModel.isSelected(.peanut))
        viewModel.toggle(.peanut)
        #expect(viewModel.isSelected(.peanut))
        viewModel.toggle(.peanut)
        #expect(!viewModel.isSelected(.peanut))
    }

    @Test func changesPersistThroughTheStore() {
        let store = InMemoryUserPreferencesStore()
        let viewModel = SettingsViewModel(store: store)

        viewModel.toggle(.dairy)
        viewModel.preferences.diet = .vegetarian

        #expect(store.load().intolerances.contains(.dairy))
        #expect(store.load().diet == .vegetarian)
    }

    @Test func loadsExistingPreferencesFromStore() {
        var prefs = UserPreferences.default
        prefs.intolerances = [.wheat]
        let store = InMemoryUserPreferencesStore(initial: prefs)

        let viewModel = SettingsViewModel(store: store)

        #expect(viewModel.isSelected(.wheat))
    }
}
