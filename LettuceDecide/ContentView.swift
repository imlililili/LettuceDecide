//
//  ContentView.swift
//  LettuceDecide
//
//  Created by Emily on 30/8/2026.
//

import SwiftUI

/// Composition root: wires the real (or mock, if no API key is configured) recipe
/// repository, the persisted pantry and preferences stores, and the recommendation use
/// case into the view models.
struct ContentView: View {
    private let preferencesStore: UserPreferencesStoring = UserPreferencesStore()
    private let pantryStore: PantryStoring = PantryStore()
    private let repository: RecipeRepository

    init() {
        if Config.spoonacularAPIKey != nil {
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
            settingsViewModel: SettingsViewModel(store: preferencesStore)
        )
    }
}

#Preview {
    ContentView()
}
