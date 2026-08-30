import SwiftUI

/// One recipe in the Recommendations list: title, how much of it the pantry covers, what's
/// missing, and whether it uses something that needs eating soon.
struct RecommendationRow: View {
    let result: PantryMatchResult

    private var matchPercent: Int { Int((result.matchPercentage * 100).rounded()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(result.recipe.title)
                    .font(.headline)
                Spacer(minLength: 8)
                if result.usesExpiringIngredients {
                    Label("Use soon", systemImage: "clock.badge.exclamationmark")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                        .labelStyle(.titleAndIcon)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: result.matchPercentage)
                    .tint(matchPercent == 100 ? .green : .accentColor)
                Text("\(matchPercent)% of ingredients in your pantry")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !result.missingIngredients.isEmpty {
                Text("Missing: \(result.missingIngredients.map(\.name).joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    List {
        RecommendationRow(result: PantryMatchResult(
            id: 1,
            recipe: Recipe(id: 1, title: "Chickpea and Spinach Curry"),
            matchedIngredients: [
                PantryIngredient(ingredientName: "chickpeas", quantity: 400, unit: .grams, storageLocation: .pantry),
                PantryIngredient(ingredientName: "spinach", quantity: 200, unit: .grams, storageLocation: .fridge, expiryDate: Date().addingTimeInterval(86_400)),
            ],
            missingIngredients: [RecipeIngredient(id: 9, name: "curry powder", requiredQuantity: 1, unit: .tablespoons)],
            usesExpiringIngredients: true
        ))
    }
}
