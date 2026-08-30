import SwiftUI

struct RecommendationView: View {
    @StateObject private var viewModel: RecommendationViewModel
    @StateObject private var settingsViewModel: SettingsViewModel
    @StateObject private var pantryViewModel: PantryViewModel
    @State private var showingSettings = false
    @State private var showingPantry = false

    init(
        viewModel: @autoclosure @escaping () -> RecommendationViewModel,
        settingsViewModel: @autoclosure @escaping () -> SettingsViewModel,
        pantryViewModel: @autoclosure @escaping () -> PantryViewModel
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        _settingsViewModel = StateObject(wrappedValue: settingsViewModel())
        _pantryViewModel = StateObject(wrappedValue: pantryViewModel())
    }

    var body: some View {
        NavigationStack {
            VStack {
                Spacer(minLength: 0)
                content
                Spacer(minLength: 0)
                decideButton
            }
            .padding()
            .navigationTitle("Lettuce Decide")
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
                if viewModel.state == .idle {
                    await viewModel.decide()
                }
            }
            .onChange(of: showingPantry) { _, isShowing in
                // Coming back from the pantry: the inventory may have changed, so re-decide.
                if !isShowing {
                    Task { await viewModel.decide() }
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            EmptyView()
        case .loading:
            LoadingView()
        case .loaded(let recipe):
            ScrollView {
                RecipeCardView(recipe: recipe)
            }
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

    private var decideButton: some View {
        Button {
            Task { await viewModel.decide() }
        } label: {
            Label("Decide For Me", systemImage: "shuffle")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.state == .loading)
        .padding(.top)
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
        pantryViewModel: PantryViewModel(store: pantryStore)
    )
}
