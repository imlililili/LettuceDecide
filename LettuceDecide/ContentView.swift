//
//  ContentView.swift
//  LettuceDecide
//
//  Created by Emily on 30/8/2026.
//

import SwiftUI

/// Composition root: wires the recipe repository (real, or mock when there's no API key or
/// during UI tests) and the persisted stores into the view models, then hands them to the
/// tab shell.
struct ContentView: View {
    private let preferencesStore: UserPreferencesStoring
    private let pantryStore: PantryStoring
    private let scheduleStore: ScheduleStoring
    private let repository: RecipeRepository

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        // -uiTesting: fully hermetic (mock recipes, in-memory stores).
        // -liveTest:  real Spoonacular, but a scratch in-memory pantry so each launch
        //             starts clean.
        let uiTesting = arguments.contains("-uiTesting")
        let scratchStores = uiTesting || arguments.contains("-liveTest")

        preferencesStore = scratchStores ? InMemoryUserPreferencesStore() : UserPreferencesStore()
        pantryStore = scratchStores ? InMemoryPantryStore() : PantryStore()
        scheduleStore = scratchStores ? InMemoryScheduleStore() : ScheduleStore()

        if !uiTesting, Config.spoonacularAPIKey != nil {
            repository = SpoonacularRecipeRepository()
        } else {
            repository = MockRecipeRepository()
        }
    }

    var body: some View {
        MainTabView(
            recommendationViewModel: RecommendationViewModel(
                recommendMeals: RecommendMealsFromPantryUseCase(
                    recipeRepository: repository,
                    pantryStore: pantryStore,
                    preferencesStore: preferencesStore
                )
            ),
            pantryViewModel: PantryViewModel(store: pantryStore),
            weeklyPlannerViewModel: WeeklyPlannerViewModel(
                recordBusyness: RecordBusynessUseCase(store: scheduleStore),
                generatePlan: GenerateWeeklyMealPlanUseCase(
                    recipeRepository: repository,
                    pantryStore: pantryStore,
                    preferencesStore: preferencesStore
                ),
                pantryStore: pantryStore
            ),
            settingsViewModel: SettingsViewModel(store: preferencesStore),
            pantryStore: pantryStore
        )
    }
}

#Preview {
    ContentView()
}
