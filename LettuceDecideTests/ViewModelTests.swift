import Testing
@testable import LettuceDecide

@MainActor
struct RecommendationViewModelTests {
    @Test func decideTransitionsFromLoadingToLoadedOnSuccess() async {
        let mock = MockRecipeRepository(fixedRecipes: [MockRecipeRepository.sampleRecipes[0]])
        let viewModel = RecommendationViewModel(
            engine: RecommendationEngine(repository: mock),
            preferencesStore: InMemoryUserPreferencesStore()
        )

        #expect(viewModel.state == .idle)
        await viewModel.decide()

        guard case .loaded(let recipe) = viewModel.state else {
            Issue.record("Expected .loaded state, got \(viewModel.state)")
            return
        }
        #expect(recipe.id == MockRecipeRepository.sampleRecipes[0].id)
    }

    @Test func decideTransitionsToFailedOnError() async {
        let mock = MockRecipeRepository(errorToThrow: RecipeRepositoryError.noResultsFound)
        let viewModel = RecommendationViewModel(
            engine: RecommendationEngine(repository: mock),
            preferencesStore: InMemoryUserPreferencesStore()
        )

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
