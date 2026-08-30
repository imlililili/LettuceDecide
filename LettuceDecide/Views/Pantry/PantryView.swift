import SwiftUI

/// The pantry inventory: ingredients grouped by storage location, each showing an expiry
/// cue. Tapping a row edits it; the toolbar "+" adds a new one.
struct PantryView: View {
    @ObservedObject var viewModel: PantryViewModel
    @State private var sheet: Sheet?

    enum Sheet: Identifiable {
        case add
        case edit(PantryIngredient)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let ingredient): return ingredient.id.uuidString
            }
        }
    }

    var body: some View {
        Group {
            if viewModel.isEmpty {
                ContentUnavailableView {
                    Label("Your pantry is empty", systemImage: "refrigerator")
                } description: {
                    Text("Add ingredients you have on hand so FridgeFit can suggest meals you can make now.")
                } actions: {
                    Button("Add Ingredient") { sheet = .add }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(viewModel.sections) { section in
                        Section(section.location.displayName) {
                            ForEach(section.ingredients) { ingredient in
                                Button {
                                    sheet = .edit(ingredient)
                                } label: {
                                    PantryRow(ingredient: ingredient)
                                }
                                .buttonStyle(.plain)
                            }
                            .onDelete { offsets in
                                viewModel.delete(at: offsets, in: section.location)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Pantry")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    sheet = .add
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Ingredient")
            }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .add:
                AddEditIngredientView(mode: .add) { draft in
                    try viewModel.add(draft)
                }
            case .edit(let ingredient):
                AddEditIngredientView(mode: .edit(ingredient)) { draft in
                    try viewModel.update(ingredient, with: draft)
                }
            }
        }
    }
}

private struct PantryRow: View {
    let ingredient: PantryIngredient

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(ingredient.ingredientName)
                Text("\(quantityText) \(ingredient.unit.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ExpiryBadge(ingredient: ingredient)
        }
    }

    private var quantityText: String {
        ingredient.quantity == ingredient.quantity.rounded()
            ? String(Int(ingredient.quantity))
            : String(ingredient.quantity)
    }
}

#Preview {
    NavigationStack {
        PantryView(viewModel: PantryViewModel(store: InMemoryPantryStore(initial: [
            PantryIngredient(ingredientName: "Spinach", quantity: 200, unit: .grams, storageLocation: .fridge, expiryDate: Date().addingTimeInterval(86_400)),
            PantryIngredient(ingredientName: "Peas", quantity: 500, unit: .grams, storageLocation: .freezer),
            PantryIngredient(ingredientName: "Rice", quantity: 1000, unit: .grams, storageLocation: .pantry),
        ])))
    }
}
