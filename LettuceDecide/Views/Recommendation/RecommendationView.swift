import SwiftUI

/// The home screen: a ranked list of recipes the cook can make from their pantry right now,
/// most-urgent-to-use and best-matched first.
struct RecommendationView: View {
    @StateObject private var viewModel: RecommendationViewModel
    @StateObject private var settingsViewModel: SettingsViewModel
    @StateObject private var pantryViewModel: PantryViewModel
    private let pantryStore: PantryStoring
    @State private var showingSettings = false
    @State private var showingPantry = false

    init(
        viewModel: @autoclosure @escaping () -> RecommendationViewModel,
        settingsViewModel: @autoclosure @escaping () -> SettingsViewModel,
        pantryViewModel: @autoclosure @escaping () -> PantryViewModel,
        pantryStore: PantryStoring
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        _settingsViewModel = StateObject(wrappedValue: settingsViewModel())
        _pantryViewModel = StateObject(wrappedValue: pantryViewModel())
        self.pantryStore = pantryStore
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Recommendations")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showingPantry = true
                        } label: {
                            Image(systemName: "refrigerator")
                        }
                        .accessibilityLabel("Pantry")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                        .accessibilityLabel("Settings")
                    }
                }
                .navigationDestination(isPresented: $showingPantry) {
                    PantryView(viewModel: pantryViewModel)
                }
                .sheet(isPresented: $showingSettings) {
                    SettingsView(viewModel: settingsViewModel)
                }
                .task {
                    if case .idle = viewModel.state {
                        await viewModel.decide()
                    }
                }
                .onChange(of: showingPantry) { _, isShowing in
                    // Returning from the pantry: the inventory may have changed, so refresh.
                    if !isShowing {
                        Task { await viewModel.decide() }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingView(message: "Finding recipes you can make…")
        case .loaded(let results):
            List(results) { result in
                NavigationLink {
                    RecipeDetailView(
                        viewModel: RecipeDetailViewModel(result: result, pantryStore: pantryStore),
                        onCooked: {
                            pantryViewModel.reload()
                            Task { await viewModel.decide() }
                        }
                    )
                } label: {
                    RecommendationRow(result: result)
                }
            }
            .listStyle(.plain)
            .refreshable { await viewModel.decide() }
        case .failed(let failure):
            ErrorStateView(
                message: failure.message,
                actionTitle: failure.recovery == .addIngredients ? "Add Ingredients" : "Try Again"
            ) {
                switch failure.recovery {
                case .retry:
                    Task { await viewModel.decide() }
                case .addIngredients:
                    showingPantry = true
                }
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
    RecommendationView(
        viewModel: RecommendationViewModel(
            recommendMeals: RecommendMealsFromPantryUseCase(
                recipeRepository: MockRecipeRepository(),
                pantryStore: pantryStore,
                preferencesStore: preferencesStore
            )
        ),
        settingsViewModel: SettingsViewModel(store: preferencesStore),
        pantryViewModel: PantryViewModel(store: pantryStore),
        pantryStore: pantryStore
    )
}
