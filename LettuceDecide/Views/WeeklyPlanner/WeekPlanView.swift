import SwiftUI

/// Result screen for the weekly planner: the seven assigned days (or an honest "no match"),
/// and the shopping list for everything the week still needs.
///
/// This is a preview — tapping a day opens the existing Recipe Detail, and only cooking a
/// recipe there touches the real pantry.
struct WeekPlanView: View {
    let plan: WeeklyMealPlan
    let pantryStore: PantryStoring
    let addToShoppingList: AddMissingIngredientsToShoppingListUseCase

    @State private var addedCount: Int?

    var body: some View {
        List {
            if plan.isFromCache {
                Section {
                    StaleResultsNotice()
                        .listRowInsets(EdgeInsets())
                }
            }

            Section("Your week") {
                ForEach(plan.days) { day in
                    if let recipe = day.assignedRecipe {
                        NavigationLink {
                            RecipeDetailView(
                                viewModel: RecipeDetailViewModel(
                                    recipe: recipe,
                                    pantryStore: pantryStore,
                                    addToShoppingList: addToShoppingList
                                ),
                                onCooked: {}
                            )
                        } label: {
                            DayRow(day: day)
                        }
                    } else {
                        DayRow(day: day)
                    }
                }
            }

            if !plan.shoppingList.isEmpty {
                Section("Shopping list") {
                    ForEach(plan.shoppingList) { item in
                        HStack {
                            Text(item.ingredientName)
                            Spacer()
                            Text("\(Self.number(item.requiredQuantity)) \(item.unit.displayName)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        let list = addToShoppingList.execute(adding: plan.shoppingList)
                        addedCount = list.count
                    } label: {
                        Label("Add all to my shopping list", systemImage: "cart.badge.plus")
                    }
                }
            } else if plan.days.contains(where: { $0.assignedRecipe != nil }) {
                Section("Shopping list") {
                    Text("Your pantry covers everything this week.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("This Week's Plan")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "Added to your shopping list",
            isPresented: Binding(get: { addedCount != nil }, set: { if !$0 { addedCount = nil } })
        ) {
            Button("OK") { addedCount = nil }
        } message: {
            Text("Your shopping list now has \(addedCount ?? 0) item\((addedCount ?? 0) == 1 ? "" : "s").")
        }
    }

    static func number(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}

private struct DayRow: View {
    let day: DayMealPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(day.date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(day.busyness.displayName)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }

            if let recipe = day.assignedRecipe {
                Text(recipe.title)
                    .font(.body)
                if let minutes = recipe.readyInMinutes {
                    Label("\(minutes) min", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No match this busy — try loosening a restriction")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let monday = WeeklyPlannerViewModel.startOfWeek(containing: Date(), calendar: .current)
    let plan = WeeklyMealPlan(
        days: (0..<7).map { offset in
            DayMealPlan(
                id: Calendar.current.date(byAdding: .day, value: offset, to: monday)!,
                busyness: offset.isMultiple(of: 2) ? .normal : .busy,
                assignedRecipe: offset == 3 ? nil : MockRecipeRepository.sampleRecipes[offset % 3]
            )
        },
        shoppingList: [
            ShoppingListItem(ingredientName: "curry powder", requiredQuantity: 2, unit: .tablespoons),
            ShoppingListItem(ingredientName: "mozzarella", requiredQuantity: 200, unit: .grams),
        ]
    )
    return NavigationStack {
        WeekPlanView(
            plan: plan,
            pantryStore: InMemoryPantryStore(),
            addToShoppingList: AddMissingIngredientsToShoppingListUseCase(store: InMemoryShoppingListStore())
        )
    }
}
