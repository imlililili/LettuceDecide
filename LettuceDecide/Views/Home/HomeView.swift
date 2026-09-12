import SwiftUI

/// The Home tab: every meal the cook has confirmed from the Week Plan, newest-day-last, and
/// the shopping list those confirmations have built up. Read-only — the shopping list is
/// already the pantry-netted, deduped result `ConfirmPlannedMealUseCase` computed at confirm
/// time; this screen just shows it.
struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel
    let pantryStore: PantryStoring
    let addToShoppingList: AddMissingIngredientsToShoppingListUseCase
    let confirmedMealStore: ConfirmedMealStoring
    /// Called when the cook has nothing confirmed yet — the shell switches to the Calendar tab.
    let onNeedsPlanning: () -> Void

    var body: some View {
        Group {
            if viewModel.isEmpty {
                ContentUnavailableView {
                    Label("No confirmed meals yet", systemImage: "house")
                } description: {
                    Text("Go to Calendar to plan your week, then confirm a day to see it here.")
                } actions: {
                    Button("Plan My Week") { onNeedsPlanning() }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    Section("This week's meals") {
                        ForEach(viewModel.confirmedMeals) { meal in
                            NavigationLink {
                                RecipeDetailView(
                                    viewModel: RecipeDetailViewModel(
                                        recipe: meal.recipe,
                                        pantryStore: pantryStore,
                                        addToShoppingList: addToShoppingList,
                                        confirmedMealStore: confirmedMealStore,
                                        context: .confirmed(date: meal.date)
                                    ),
                                    onCooked: { viewModel.reload() }
                                )
                            } label: {
                                ConfirmedMealCard(meal: meal)
                            }
                        }
                    }

                    if !viewModel.shoppingList.isEmpty {
                        Section("Shopping list") {
                            ForEach(viewModel.shoppingList) { item in
                                ShoppingListItemRow(item: item)
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            viewModel.markAsBought(item)
                                        } label: {
                                            Label("Bought", systemImage: "checkmark")
                                        }
                                        .tint(.green)
                                    }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Home")
        .sheet(item: $viewModel.pendingUncertainPurchase) { item in
            ConfirmPurchaseAmountView(
                item: item,
                onConfirm: { quantity, unit in viewModel.confirmUncertainPurchase(quantity: quantity, unit: unit) },
                onCancel: { viewModel.cancelUncertainPurchase() }
            )
        }
        .alert(
            "Couldn't add to your pantry",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

/// One confirmed meal on the Home dashboard: the day, and just enough of the recipe to
/// recognise it — an image and its title, nothing else, so the list stays scannable.
private struct ConfirmedMealCard: View {
    let meal: ConfirmedMeal

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: meal.recipe.imageURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    imagePlaceholder
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(meal.date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(meal.recipe.title)
                    .font(.headline)
            }
        }
        .padding(.vertical, 4)
    }

    private var imagePlaceholder: some View {
        Rectangle()
            .fill(.green.opacity(0.15))
            .overlay(Image(systemName: "fork.knife").foregroundStyle(.green))
    }
}

#Preview("With confirmed meals") {
    let monday = WeeklyPlannerViewModel.startOfWeek(containing: Date(), calendar: .current)
    let confirmedMealStore = InMemoryConfirmedMealStore(initial: [
        ConfirmedMeal(date: monday, recipe: MockRecipeRepository.sampleRecipes[1]),
        ConfirmedMeal(
            date: Calendar.current.date(byAdding: .day, value: 2, to: monday)!,
            recipe: MockRecipeRepository.sampleRecipes[2]
        ),
    ])
    let shoppingListStore = InMemoryShoppingListStore(initial: [
        ShoppingListItem(ingredientName: "curry powder", requiredQuantity: 1, unit: .tablespoons, ingredientId: 1_022_047),
        ShoppingListItem(ingredientName: "mozzarella", requiredQuantity: 200, unit: .grams, ingredientId: 1026),
        ShoppingListItem(ingredientName: "green onions", requiredQuantity: 4, unit: .pieces, quantityIsUncertain: true),
    ])
    let pantryStore = InMemoryPantryStore()
    return NavigationStack {
        HomeView(
            viewModel: HomeViewModel(
                confirmedMealStore: confirmedMealStore,
                shoppingListStore: shoppingListStore,
                pantryStore: pantryStore
            ),
            pantryStore: pantryStore,
            addToShoppingList: AddMissingIngredientsToShoppingListUseCase(store: shoppingListStore),
            confirmedMealStore: confirmedMealStore,
            onNeedsPlanning: {}
        )
    }
}

#Preview("Empty") {
    let pantryStore = InMemoryPantryStore()
    return NavigationStack {
        HomeView(
            viewModel: HomeViewModel(
                confirmedMealStore: InMemoryConfirmedMealStore(),
                shoppingListStore: InMemoryShoppingListStore(),
                pantryStore: pantryStore
            ),
            pantryStore: pantryStore,
            addToShoppingList: AddMissingIngredientsToShoppingListUseCase(store: InMemoryShoppingListStore()),
            confirmedMealStore: InMemoryConfirmedMealStore(),
            onNeedsPlanning: {}
        )
    }
}
