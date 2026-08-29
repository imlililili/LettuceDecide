//
//  ContentView.swift
//  LettuceDecide
//
//  Created by Emily on 30/8/2026.
//

import SwiftUI

/// Composition root: wires the real (or mock, if no API key is configured) repository,
/// the recommendation engine, and the persisted preferences store into the view models.
struct ContentView: View {
    private let preferencesStore: UserPreferencesStoring = UserPreferencesStore()
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
                engine: RecommendationEngine(repository: repository),
                preferencesStore: preferencesStore
            ),
            settingsViewModel: SettingsViewModel(store: preferencesStore)
        )
    }
}

#Preview {
    ContentView()
}
