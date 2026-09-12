import SwiftUI

/// A small sheet asking the cook for the real amount they bought, for a shopping-list line
/// whose own amount wasn't trustworthy (`ShoppingListItem.quantityIsUncertain` — e.g.
/// Spoonacular's raw unit was "servings", not a real count). Mirrors the Quantity + Unit
/// fields on `AddEditIngredientView`'s Amount section so entering a real amount feels like
/// the same action the cook already knows from Pantry.
struct ConfirmPurchaseAmountView: View {
    let item: ShoppingListItem
    let onConfirm: (Double, IngredientUnit) -> Void
    let onCancel: () -> Void

    @State private var quantity: Double = 1
    @State private var unit: IngredientUnit = .pieces

    init(item: ShoppingListItem, onConfirm: @escaping (Double, IngredientUnit) -> Void, onCancel: @escaping () -> Void) {
        self.item = item
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("The amount for \(item.ingredientName) wasn't clear from the recipe. Enter how much you actually bought.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Section("Amount") {
                    HStack {
                        TextField("Quantity", value: $quantity, format: .number)
                            .keyboardType(.decimalPad)
                        Picker("Unit", selection: $unit) {
                            ForEach(IngredientUnit.allCases) { Text($0.displayName).tag($0) }
                        }
                        .labelsHidden()
                    }
                }
            }
            .navigationTitle("Confirm Amount")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add to Pantry") { onConfirm(quantity, unit) }
                        .disabled(quantity <= 0)
                }
            }
        }
    }
}

#Preview {
    ConfirmPurchaseAmountView(
        item: ShoppingListItem(ingredientName: "green onions", requiredQuantity: 4, unit: .pieces, quantityIsUncertain: true),
        onConfirm: { _, _ in },
        onCancel: {}
    )
}
