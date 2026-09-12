import SwiftUI

/// One shopping-list line: the ingredient, and either its amount or — when
/// `ShoppingListItem.quantityIsUncertain` is set — an honest admission that the app
/// couldn't determine a real quantity, instead of a confident-looking wrong number.
///
/// Shared by the Home dashboard and the Week Plan preview, which both display the same
/// `ShoppingListItem` data.
struct ShoppingListItemRow: View {
    let item: ShoppingListItem

    var body: some View {
        HStack {
            Text(item.ingredientName)
            Spacer()
            if item.quantityIsUncertain {
                Text("Amount unclear — check the recipe")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Text("\(Self.number(item.requiredQuantity)) \(item.unit.displayName)")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private static func number(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}

#Preview {
    List {
        ShoppingListItemRow(item: ShoppingListItem(ingredientName: "flour", requiredQuantity: 500, unit: .grams))
        ShoppingListItemRow(item: ShoppingListItem(
            ingredientName: "green onions",
            requiredQuantity: 4,
            unit: .pieces,
            quantityIsUncertain: true
        ))
    }
}
