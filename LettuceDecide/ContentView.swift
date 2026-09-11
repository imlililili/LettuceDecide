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
    private let shoppingListStore: ShoppingListStoring
    private let confirmedMealStore: ConfirmedMealStoring
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
        shoppingListStore = scratchStores ? InMemoryShoppingListStore() : ShoppingListStore()
        confirmedMealStore = scratchStores ? InMemoryConfirmedMealStore() : ConfirmedMealStore()

        if !uiTesting, Config.spoonacularAPIKey != nil {
            // The real API sits behind a cache so an unreachable network falls back to the
            // last good result instead of an error. A scratch launch uses an in-memory cache
            // so it can't be primed by a previous run.
            let cache: RecipeCacheStoring = scratchStores ? InMemoryRecipeCacheStore() : RecipeCacheStore()
            repository = CachingRecipeRepository(wrapping: SpoonacularRecipeRepository(), cache: cache)
        } else {
            // -uiTestNoRefetch: the first recipe fetch succeeds, any later one fails — so a
            // UI test can tell "re-ranked locally" (list updates) from "refetched" (error).
            let failAfterCall = arguments.contains("-uiTestNoRefetch") ? 1 : nil
            repository = MockRecipeRepository(failAfterCall: failAfterCall)
        }
    }

    var body: some View {
        MainTabView(
            homeViewModel: HomeViewModel(
                confirmedMealStore: confirmedMealStore,
                shoppingListStore: shoppingListStore
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
            pantryStore: pantryStore,
            addToShoppingList: AddMissingIngredientsToShoppingListUseCase(store: shoppingListStore),
            confirmedMealStore: confirmedMealStore
        )
    }
}

#Preview {
    ContentView()
}
