import Foundation
import Testing
@testable import LettuceDecide

struct PantryMatcherTests {
    private let today = Date(timeIntervalSince1970: 1_700_000_000)
    private var inTwoDays: Date { Calendar.current.date(byAdding: .day, value: 2, to: today)! }

    private func recipe(_ id: Int) -> Recipe { Recipe(id: id, title: "Recipe \(id)") }

    @Test func mapsUsedNamesOntoPantryLinesIgnoringPluralAndCase() {
        let pantry = [
            PantryIngredient(ingredientName: "Tomatoes", quantity: 3, unit: .pieces, storageLocation: .fridge),
            PantryIngredient(ingredientName: "rice", quantity: 500, unit: .grams, storageLocation: .pantry),
        ]
        let candidate = PantryRecipeCandidate(
            recipe: recipe(1),
            usedIngredientNames: ["tomato"],
            missedIngredients: []
        )

        let result = PantryMatcher().match(candidates: [candidate], against: pantry, now: today)

        #expect(result.first?.matchedIngredients.map(\.ingredientName) == ["Tomatoes"])
    }

    @Test func carriesTheCandidateCacheFlagOntoEachResult() {
        let fresh = PantryRecipeCandidate(recipe: recipe(1), usedIngredientNames: [], missedIngredients: [])
        var cached = PantryRecipeCandidate(recipe: recipe(2), usedIngredientNames: [], missedIngredients: [])
        cached.isFromCache = true

        let results = PantryMatcher().match(candidates: [fresh, cached], against: [], now: today)

        let freshResult = results.first { $0.recipe.id == 1 }
        let cachedResult = results.first { $0.recipe.id == 2 }
        #expect(freshResult?.isFromCache == false)
        #expect(cachedResult?.isFromCache == true)
    }

    @Test func matchPercentageIsMatchedOverMatchedPlusMissing() {
        let pantry = [PantryIngredient(ingredientName: "egg", quantity: 6, unit: .pieces, storageLocation: .fridge)]
        let candidate = PantryRecipeCandidate(
            recipe: recipe(1),
            usedIngredientNames: ["egg"],
            missedIngredients: [
                RecipeIngredient(id: 1, name: "flour", requiredQuantity: 200, unit: .grams),
                RecipeIngredient(id: 2, name: "milk", requiredQuantity: 100, unit: .millilitres),
            ]
        )

        let result = PantryMatcher().match(candidates: [candidate], against: pantry, now: today)

        #expect(result.first?.matchPercentage == 1.0 / 3.0)
    }

    @Test func flagsExpiringWhenAMatchedPantryLineIsExpiringSoon() {
        let pantry = [
            PantryIngredient(ingredientName: "spinach", quantity: 200, unit: .grams, storageLocation: .fridge, expiryDate: inTwoDays)
        ]
        let candidate = PantryRecipeCandidate(recipe: recipe(1), usedIngredientNames: ["spinach"], missedIngredients: [])

        let result = PantryMatcher().match(candidates: [candidate], against: pantry, now: today)

        #expect(result.first?.usesExpiringIngredients == true)
    }

    @Test func recipesUsingExpiringIngredientsRankAboveHigherMatchesThatDoNot() {
        let pantry = [
            PantryIngredient(ingredientName: "tomato", quantity: 3, unit: .pieces, storageLocation: .fridge, expiryDate: inTwoDays),
            PantryIngredient(ingredientName: "rice", quantity: 500, unit: .grams, storageLocation: .pantry),
            PantryIngredient(ingredientName: "beans", quantity: 400, unit: .grams, storageLocation: .pantry),
        ]
        let fullMatchNoExpiry = PantryRecipeCandidate(
            recipe: recipe(1),
            usedIngredientNames: ["rice", "beans"],
            missedIngredients: []
        )
        let lowMatchUsesExpiring = PantryRecipeCandidate(
            recipe: recipe(2),
            usedIngredientNames: ["tomato"],
            missedIngredients: [
                RecipeIngredient(id: 1, name: "basil", requiredQuantity: 1, unit: .pieces),
                RecipeIngredient(id: 2, name: "mozzarella", requiredQuantity: 200, unit: .grams),
            ]
        )

        let ranked = PantryMatcher().match(
            candidates: [fullMatchNoExpiry, lowMatchUsesExpiring],
            against: pantry,
            now: today
        )

        #expect(ranked.map(\.recipe.id) == [2, 1])
    }

    @Test func withinTheSameExpiryGroupHigherMatchComesFirst() {
        let pantry = [
            PantryIngredient(ingredientName: "onion", quantity: 2, unit: .pieces, storageLocation: .pantry),
            PantryIngredient(ingredientName: "garlic", quantity: 3, unit: .pieces, storageLocation: .pantry),
        ]
        let lowMatch = PantryRecipeCandidate(
            recipe: recipe(1),
            usedIngredientNames: ["onion"],
            missedIngredients: [RecipeIngredient(id: 1, name: "beef", requiredQuantity: 300, unit: .grams)]
        )
        let highMatch = PantryRecipeCandidate(
            recipe: recipe(2),
            usedIngredientNames: ["onion", "garlic"],
            missedIngredients: []
        )

        let ranked = PantryMatcher().match(candidates: [lowMatch, highMatch], against: pantry, now: today)

        #expect(ranked.map(\.recipe.id) == [2, 1])
    }
}
