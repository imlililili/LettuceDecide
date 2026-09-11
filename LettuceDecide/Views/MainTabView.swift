import SwiftUI

/// The app shell: four peer tabs, each with its own independent `NavigationStack` so
/// switching tabs never disturbs another tab's navigation.
struct MainTabView: View {
    enum Tab: Hashable {
        case decide
        case pantry
        case calendar
        case settings
    }

    @StateObject private var recommendationViewModel: RecommendationViewModel
    @StateObject private var pantryViewModel: PantryViewModel
    @StateObject private var weeklyPlannerViewModel: WeeklyPlannerViewModel
    @StateObject private var settingsViewModel: SettingsViewModel
    private let pantryStore: PantryStoring
    private let addToShoppingList: AddMissingIngredientsToShoppingListUseCase
    private let confirmedMealStore: ConfirmedMealStoring

    @State private var selectedTab: Tab = .decide

    init(
        recommendationViewModel: @autoclosure @escaping () -> RecommendationViewModel,
        pantryViewModel: @autoclosure @escaping () -> PantryViewModel,
        weeklyPlannerViewModel: @autoclosure @escaping () -> WeeklyPlannerViewModel,
        settingsViewModel: @autoclosure @escaping () -> SettingsViewModel,
        pantryStore: PantryStoring,
        addToShoppingList: AddMissingIngredientsToShoppingListUseCase,
        confirmedMealStore: ConfirmedMealStoring
    ) {
        _recommendationViewModel = StateObject(wrappedValue: recommendationViewModel())
        _pantryViewModel = StateObject(wrappedValue: pantryViewModel())
        _weeklyPlannerViewModel = StateObject(wrappedValue: weeklyPlannerViewModel())
        _settingsViewModel = StateObject(wrappedValue: settingsViewModel())
        self.pantryStore = pantryStore
        self.addToShoppingList = addToShoppingList
        self.confirmedMealStore = confirmedMealStore
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                RecommendationView(
                    viewModel: recommendationViewModel,
                    pantryStore: pantryStore,
                    addToShoppingList: addToShoppingList,
                    confirmedMealStore: confirmedMealStore,
                    onNeedsPantry: { selectedTab = .pantry }
                )
            }
            .tabItem { Label("Decide", systemImage: "fork.knife") }
            .tag(Tab.decide)

            NavigationStack {
                PantryView(viewModel: pantryViewModel)
            }
            .tabItem { Label("Pantry", systemImage: "basket") }
            .tag(Tab.pantry)

            NavigationStack {
                WeeklyPlannerView(
                    viewModel: weeklyPlannerViewModel,
                    addToShoppingList: addToShoppingList,
                    confirmedMealStore: confirmedMealStore
                )
            }
            .tabItem { Label("Calendar", systemImage: "calendar") }
            .tag(Tab.calendar)

            NavigationStack {
                SettingsView(viewModel: settingsViewModel)
            }
            .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
            .tag(Tab.settings)
        }
        .onChange(of: selectedTab) { _, tab in
            switch tab {
            case .decide:
                // Retry a failed load — the cook may have just added the pantry ingredient
                // that was missing. A loaded list is left alone (no silent refetch).
                if case .failed = recommendationViewModel.state {
                    Task { await recommendationViewModel.decide() }
                }
            case .pantry:
                // A cooked recipe or a generated plan on another tab may have moved stock.
                pantryViewModel.reload()
            case .calendar, .settings:
                break
            }
        }
    }
}

#Preview {
    let pantryStore = InMemoryPantryStore(initial: [
        PantryIngredient(ingredientName: "chickpeas", quantity: 400, unit: .grams, storageLocation: .pantry),
        PantryIngredient(ingredientName: "spinach", quantity: 200, unit: .grams, storageLocation: .fridge),
    ])
    let preferencesStore = InMemoryUserPreferencesStore()
    return MainTabView(
        recommendationViewModel: RecommendationViewModel(
            recommendMeals: RecommendMealsFromPantryUseCase(
                recipeRepository: MockRecipeRepository(),
                pantryStore: pantryStore,
                preferencesStore: preferencesStore
            )
        ),
        pantryViewModel: PantryViewModel(store: pantryStore),
        weeklyPlannerViewModel: WeeklyPlannerViewModel(
            recordBusyness: RecordBusynessUseCase(store: InMemoryScheduleStore()),
            generatePlan: GenerateWeeklyMealPlanUseCase(
                recipeRepository: MockRecipeRepository(),
                pantryStore: pantryStore,
                preferencesStore: preferencesStore
            ),
            pantryStore: pantryStore
        ),
        settingsViewModel: SettingsViewModel(store: preferencesStore),
        pantryStore: pantryStore,
        addToShoppingList: AddMissingIngredientsToShoppingListUseCase(store: InMemoryShoppingListStore()),
        confirmedMealStore: InMemoryConfirmedMealStore()
    )
}
