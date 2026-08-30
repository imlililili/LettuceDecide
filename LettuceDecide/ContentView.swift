//
//  ContentView.swift
//  LettuceDecide
//
//  Created by Emily on 30/8/2026.
//

import SwiftUI

/// Composition root: wires the recipe repository (real, or mock when there's no API key or
/// during UI tests), the persisted pantry and preferences stores, and the recommendation
/// use case into the view models.
struct ContentView: View {
    private let preferencesStore: UserPreferencesStoring
    private let pantryStore: PantryStoring
    private let repository: RecipeRepository

    init() {
        let uiTesting = ProcessInfo.processInfo.arguments.contains("-uiTesting")
        preferencesStore = uiTesting ? InMemoryUserPreferencesStore() : UserPreferencesStore()
        pantryStore = uiTesting ? InMemoryPantryStore() : PantryStore()

        if !uiTesting, Config.spoonacularAPIKey != nil {
            repository = SpoonacularRecipeRepository()
        } else {
            repository = MockRecipeRepository()
        }
    }

    var body: some View {
        RecommendationView(
            viewModel: RecommendationViewModel(
                recommendMeals: RecommendMealsFromPantryUseCase(
                    recipeRepository: repository,
                    pantryStore: pantryStore,
                    preferencesStore: preferencesStore
                )
            ),
            settingsViewModel: SettingsViewModel(store: preferencesStore),
            pantryViewModel: PantryViewModel(store: pantryStore)
        )
    }
}

#Preview {
    ContentView()
}
