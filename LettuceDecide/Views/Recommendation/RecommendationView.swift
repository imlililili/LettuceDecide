import SwiftUI

/// The "Decide" tab: a ranked list of recipes the cook can make from their pantry right now,
/// most-urgent-to-use and best-matched first.
struct RecommendationView: View {
    @ObservedObject var viewModel: RecommendationViewModel
    let pantryStore: PantryStoring
    let addToShoppingList: AddMissingIngredientsToShoppingListUseCase
    let confirmedMealStore: ConfirmedMealStoring
    /// Called when the cook has no pantry to recommend from — the shell switches to the
    /// Pantry tab.
    let onNeedsPantry: () -> Void

    var body: some View {
        content
            .navigationTitle("Recommendations")
            .task {
                // First load only. A loaded list is never silently refetched on reappear —
                // only "Try Again", cooking a recipe, or pull-to-refresh does that. (The
                // shell retries a *failed* load when the cook returns to this tab.)
                if case .idle = viewModel.state {
                    await viewModel.decide()
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingView(message: "Finding recipes you can make…")
        case .loaded(let results):
            VStack(spacing: 0) {
                if results.first?.isFromCache == true {
                    StaleResultsNotice()
                }
                List(results) { result in
                    NavigationLink {
                        RecipeDetailView(
                            viewModel: RecipeDetailViewModel(
                                recipe: result.recipe,
                                pantryStore: pantryStore,
                                addToShoppingList: addToShoppingList,
                                confirmedMealStore: confirmedMealStore,
                                context: .decide
                            ),
                            onCooked: {
                                Task { await viewModel.decide() }
                            }
                        )
                    } label: {
                        RecommendationRow(result: result)
                    }
                }
                .listStyle(.plain)
                .refreshable { await viewModel.decide() }
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
                    onNeedsPantry()
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
    return NavigationStack {
        RecommendationView(
            viewModel: RecommendationViewModel(
                recommendMeals: RecommendMealsFromPantryUseCase(
                    recipeRepository: MockRecipeRepository(),
                    pantryStore: pantryStore,
                    preferencesStore: preferencesStore
                )
            ),
            pantryStore: pantryStore,
            addToShoppingList: AddMissingIngredientsToShoppingListUseCase(store: InMemoryShoppingListStore()),
            confirmedMealStore: InMemoryConfirmedMealStore(),
            onNeedsPantry: {}
        )
    }
}
