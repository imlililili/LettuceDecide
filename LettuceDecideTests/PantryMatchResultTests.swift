import Foundation
import Testing
@testable import LettuceDecide

struct PantryMatchResultMatchingTests {
    private let recipe = Recipe(
        id: 1,
        title: "Chickpea stew",
        requiredIngredients: [
            RecipeIngredient(id: 1, name: "chickpeas", requiredQuantity: 400, unit: .grams),
            RecipeIngredient(id: 2, name: "curry powder", requiredQuantity: 1, unit: .tablespoons),
        ]
    )

    @Test func splitsRequiredIngredientsIntoHaveAndMissingByName() {
        let pantry = [
            PantryIngredient(ingredientName: "Chickpeas", quantity: 200, unit: .grams, storageLocation: .pantry)
        ]

        let result = PantryMatchResult.matching(recipe, against: pantry)

        #expect(result.matchedIngredients.map(\.ingredientName) == ["Chickpeas"])
        #expect(result.missingIngredients.map(\.name) == ["curry powder"])
    }

    @Test func flagsExpiringMatchedIngredients() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let pantry = [
            PantryIngredient(
                ingredientName: "chickpeas",
                quantity: 400,
                unit: .grams,
                storageLocation: .pantry,
                expiryDate: now.addingTimeInterval(86_400)
            )
        ]

        let result = PantryMatchResult.matching(recipe, against: pantry, now: now)

        #expect(result.usesExpiringIngredients)
    }
}
