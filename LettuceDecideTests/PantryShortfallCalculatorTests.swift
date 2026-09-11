import Foundation
import Testing
@testable import LettuceDecide

struct PantryShortfallCalculatorTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func recipe(_ id: Int, ingredients: [RecipeIngredient]) -> Recipe {
        Recipe(id: id, title: "Recipe \(id)", requiredIngredients: ingredients)
    }

    private func ingredient(_ id: Int, _ name: String, _ qty: Double, _ unit: IngredientUnit) -> RecipeIngredient {
        RecipeIngredient(id: id, name: name, requiredQuantity: qty, unit: unit)
    }

    @Test func aFullyMissingIngredientIsBoughtInFull() {
        var pantry = [PantryIngredient(ingredientName: "onion", quantity: 3, unit: .pieces, storageLocation: .pantry)]

        let toBuy = PantryShortfallCalculator.stillNeeded(
            for: recipe(1, ingredients: [ingredient(1, "salmon", 2, .pieces)]),
            from: &pantry,
            now: now
        )

        #expect(toBuy.count == 1)
        #expect(toBuy.first?.ingredientName == "salmon")
        #expect(toBuy.first?.requiredQuantity == 2)
        #expect(pantry.count == 1) // untouched — onion was never involved
    }

    @Test func anIngredientThePantryHasEnoughOfIsDeductedAndNothingIsBought() {
        var pantry = [PantryIngredient(ingredientName: "flour", quantity: 500, unit: .grams, storageLocation: .pantry)]

        let toBuy = PantryShortfallCalculator.stillNeeded(
            for: recipe(1, ingredients: [ingredient(1, "flour", 200, .grams)]),
            from: &pantry,
            now: now
        )

        #expect(toBuy.isEmpty)
        #expect(pantry.first?.quantity == 300)
    }

    @Test func aLineDrainedToExactlyZeroIsRemoved() {
        var pantry = [PantryIngredient(ingredientName: "flour", quantity: 200, unit: .grams, storageLocation: .pantry)]

        let toBuy = PantryShortfallCalculator.stillNeeded(
            for: recipe(1, ingredients: [ingredient(1, "flour", 200, .grams)]),
            from: &pantry,
            now: now
        )

        #expect(toBuy.isEmpty)
        #expect(pantry.isEmpty)
    }

    @Test func aPartialAmountIsDrainedAndTheDifferenceIsBought() {
        var pantry = [PantryIngredient(ingredientName: "chickpeas", quantity: 100, unit: .grams, storageLocation: .pantry)]

        let toBuy = PantryShortfallCalculator.stillNeeded(
            for: recipe(1, ingredients: [ingredient(1, "chickpeas", 400, .grams)]),
            from: &pantry,
            now: now
        )

        #expect(pantry.isEmpty)
        #expect(toBuy.first?.ingredientName == "chickpeas")
        #expect(toBuy.first?.requiredQuantity == 300)
    }

    @Test func anIngredientHeldInADifferentUnitIsLeftAloneAndNotTreatedAsMissing() {
        var pantry = [PantryIngredient(ingredientName: "flour", quantity: 2, unit: .cups, storageLocation: .pantry)]

        let toBuy = PantryShortfallCalculator.stillNeeded(
            for: recipe(1, ingredients: [ingredient(1, "flour", 300, .grams)]),
            from: &pantry,
            now: now
        )

        #expect(toBuy.isEmpty)
        #expect(pantry.first?.quantity == 2) // untouched, not deducted, not guessed at
    }

    @Test func threadingTheSameVirtualPantryAcrossTwoRecipesSplitsTheSharedStock() {
        var pantry = [PantryIngredient(ingredientName: "chickpeas", quantity: 400, unit: .grams, storageLocation: .pantry)]

        let firstShortfall = PantryShortfallCalculator.stillNeeded(
            for: recipe(1, ingredients: [ingredient(1, "chickpeas", 300, .grams)]),
            from: &pantry,
            now: now
        )
        let secondShortfall = PantryShortfallCalculator.stillNeeded(
            for: recipe(2, ingredients: [ingredient(1, "chickpeas", 300, .grams)]),
            from: &pantry,
            now: now
        )

        // First recipe used 300 of 400; second needs 300 but only 100 is left → buy 200.
        #expect(firstShortfall.isEmpty)
        #expect(secondShortfall.first?.requiredQuantity == 200)
        #expect(pantry.isEmpty)
    }
}
