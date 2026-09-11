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
                                HStack {
                                    Text(item.ingredientName)
                                    Spacer()
                                    Text("\(Self.number(item.requiredQuantity)) \(item.unit.displayName)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Home")
    }

    static func number(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
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
        ShoppingListItem(ingredientName: "curry powder", requiredQuantity: 1, unit: .tablespoons),
        ShoppingListItem(ingredientName: "mozzarella", requiredQuantity: 200, unit: .grams),
    ])
    return NavigationStack {
        HomeView(
            viewModel: HomeViewModel(confirmedMealStore: confirmedMealStore, shoppingListStore: shoppingListStore),
            pantryStore: InMemoryPantryStore(),
            addToShoppingList: AddMissingIngredientsToShoppingListUseCase(store: shoppingListStore),
            confirmedMealStore: confirmedMealStore,
            onNeedsPlanning: {}
        )
    }
}

#Preview("Empty") {
    NavigationStack {
        HomeView(
            viewModel: HomeViewModel(
                confirmedMealStore: InMemoryConfirmedMealStore(),
                shoppingListStore: InMemoryShoppingListStore()
            ),
            pantryStore: InMemoryPantryStore(),
            addToShoppingList: AddMissingIngredientsToShoppingListUseCase(store: InMemoryShoppingListStore()),
            confirmedMealStore: InMemoryConfirmedMealStore(),
            onNeedsPlanning: {}
        )
    }
}
