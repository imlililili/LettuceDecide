import SwiftUI

/// The visual expiry cue shown on every pantry row.
struct ExpiryBadge: View {
    let ingredient: PantryIngredient
    var now: Date = Date()

    var body: some View {
        switch ingredient.expiryStatus(asOf: now) {
        case .fresh where ingredient.expiryDate == nil:
            Text("No date")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        case .fresh:
            badge("Fresh", systemImage: "checkmark.circle", tint: .green)
        case .expiringSoon(let days):
            badge(days == 0 ? "Use today" : "\(days)d left", systemImage: "clock.badge.exclamationmark", tint: .orange)
        case .expired:
            badge("Expired", systemImage: "xmark.octagon", tint: .red)
        }
    }

    private func badge(_ text: String, systemImage: String, tint: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.15), in: Capsule())
            .foregroundStyle(tint)
    }
}

#Preview {
    VStack(alignment: .trailing, spacing: 8) {
        ExpiryBadge(ingredient: PantryIngredient(ingredientName: "Milk", quantity: 1, unit: .millilitres, storageLocation: .fridge, expiryDate: Date().addingTimeInterval(86_400)))
        ExpiryBadge(ingredient: PantryIngredient(ingredientName: "Bread", quantity: 1, unit: .pieces, storageLocation: .pantry, expiryDate: Date().addingTimeInterval(-86_400)))
        ExpiryBadge(ingredient: PantryIngredient(ingredientName: "Rice", quantity: 1, unit: .grams, storageLocation: .pantry))
    }
    .padding()
}
