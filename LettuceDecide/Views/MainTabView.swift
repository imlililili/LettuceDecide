import SwiftUI

/// The app shell: four peer tabs, each with its own independent `NavigationStack` so
/// switching tabs never disturbs another tab's navigation.
struct MainTabView: View {
    enum Tab: Hashable {
        case home
        case pantry
        case calendar
        case settings
    }

    @StateObject private var homeViewModel: HomeViewModel
    @StateObject private var pantryViewModel: PantryViewModel
    @StateObject private var weeklyPlannerViewModel: WeeklyPlannerViewModel
    @StateObject private var settingsViewModel: SettingsViewModel
    private let pantryStore: PantryStoring
    private let addToShoppingList: AddMissingIngredientsToShoppingListUseCase
    private let confirmedMealStore: ConfirmedMealStoring

    @State private var selectedTab: Tab = .home

    init(
        homeViewModel: @autoclosure @escaping () -> HomeViewModel,
        pantryViewModel: @autoclosure @escaping () -> PantryViewModel,
        weeklyPlannerViewModel: @autoclosure @escaping () -> WeeklyPlannerViewModel,
        settingsViewModel: @autoclosure @escaping () -> SettingsViewModel,
        pantryStore: PantryStoring,
        addToShoppingList: AddMissingIngredientsToShoppingListUseCase,
        confirmedMealStore: ConfirmedMealStoring
    ) {
        _homeViewModel = StateObject(wrappedValue: homeViewModel())
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
                HomeView(
                    viewModel: homeViewModel,
                    pantryStore: pantryStore,
                    addToShoppingList: addToShoppingList,
                    confirmedMealStore: confirmedMealStore,
                    onNeedsPlanning: { selectedTab = .calendar }
                )
            }
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(Tab.home)

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
            case .home:
                // A day confirmed on another tab, or a meal marked cooked from within Home's
                // own stack, may have changed what belongs here.
                homeViewModel.reload()
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
    let confirmedMealStore = InMemoryConfirmedMealStore()
    let shoppingListStore = InMemoryShoppingListStore()
    return MainTabView(
        homeViewModel: HomeViewModel(
            confirmedMealStore: confirmedMealStore,
            shoppingListStore: shoppingListStore,
            pantryStore: pantryStore
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
        addToShoppingList: AddMissingIngredientsToShoppingListUseCase(store: shoppingListStore),
        confirmedMealStore: confirmedMealStore
    )
}
