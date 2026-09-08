import SwiftUI

/// Input screen for the weekly planner: pick a busyness level for each of the seven days,
/// then generate a plan against the current pantry.
struct WeeklyPlannerView: View {
    @ObservedObject var viewModel: WeeklyPlannerViewModel
    let addToShoppingList: AddMissingIngredientsToShoppingListUseCase

    var body: some View {
        Form {
            Section {
                ForEach($viewModel.days) { $day in
                    DayBusynessRow(day: $day)
                }
            } header: {
                Text("How busy are you this week?")
            } footer: {
                Text("Busier days get quicker recipes with fewer ingredients. Relaxed days can take anything.")
            }
        }
        .navigationTitle("Weekly Planner")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await viewModel.generate() }
            } label: {
                Group {
                    if viewModel.isGenerating {
                        ProgressView()
                    } else {
                        Text("Generate This Week's Plan").font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isGenerating)
            .padding()
            .background(.bar)
        }
        .navigationDestination(isPresented: planReadyBinding) {
            if case .generated(let plan) = viewModel.state {
                WeekPlanView(
                    plan: plan,
                    pantryStore: viewModel.pantryStore,
                    addToShoppingList: addToShoppingList
                )
            }
        }
        .alert(
            "Couldn't build your plan",
            isPresented: failureBinding,
            presenting: failureMessage
        ) { _ in
            Button("OK") { viewModel.backToEditing() }
        } message: { message in
            Text(message)
        }
    }

    private var planReadyBinding: Binding<Bool> {
        Binding(
            get: { if case .generated = viewModel.state { return true } else { return false } },
            set: { isShowing in
                if !isShowing { viewModel.backToEditing() }
            }
        )
    }

    private var failureBinding: Binding<Bool> {
        Binding(
            get: { if case .failed = viewModel.state { return true } else { return false } },
            set: { _ in }
        )
    }

    private var failureMessage: String? {
        if case .failed(let message) = viewModel.state { return message }
        return nil
    }
}

/// One day's row on the planner: the date, and a segmented busyness picker.
private struct DayBusynessRow: View {
    @Binding var day: WeeklyPlannerViewModel.Day

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(day.date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                .font(.subheadline.weight(.medium))
            Picker("Busyness", selection: $day.busyness) {
                ForEach(BusynessLevel.allCases) { level in
                    Text(level.displayName).tag(level)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let pantryStore = InMemoryPantryStore(initial: [
        PantryIngredient(ingredientName: "chickpeas", quantity: 400, unit: .grams, storageLocation: .pantry),
        PantryIngredient(ingredientName: "spinach", quantity: 200, unit: .grams, storageLocation: .fridge),
    ])
    let preferencesStore = InMemoryUserPreferencesStore()
    return NavigationStack {
        WeeklyPlannerView(
            viewModel: WeeklyPlannerViewModel(
                recordBusyness: RecordBusynessUseCase(store: InMemoryScheduleStore()),
                generatePlan: GenerateWeeklyMealPlanUseCase(
                    recipeRepository: MockRecipeRepository(),
                    pantryStore: pantryStore,
                    preferencesStore: preferencesStore
                ),
                pantryStore: pantryStore
            ),
            addToShoppingList: AddMissingIngredientsToShoppingListUseCase(store: InMemoryShoppingListStore())
        )
    }
}
