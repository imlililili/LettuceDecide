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

    /// Genuinely cross-group (weight vs volume) — flour in cups can't be safely compared to
    /// flour in grams — so this stays left-alone after the volume-conversion fix too.
    @Test func anIngredientHeldInAnUnconvertibleUnitIsLeftAloneAndNotTreatedAsMissing() {
        var pantry = [PantryIngredient(ingredientName: "flour", quantity: 2, unit: .cups, storageLocation: .pantry)]

        let toBuy = PantryShortfallCalculator.stillNeeded(
            for: recipe(1, ingredients: [ingredient(1, "flour", 300, .grams)]),
            from: &pantry,
            now: now
        )

        #expect(toBuy.isEmpty)
        #expect(pantry.first?.quantity == 2) // untouched, not deducted, not guessed at
    }

    // MARK: - Same-measurement-group volume conversion

    @Test func aDifferentButConvertibleVolumeUnitIsDeductedNormally() {
        var pantry = [PantryIngredient(ingredientName: "olive oil", quantity: 480, unit: .millilitres, storageLocation: .pantry)]

        let toBuy = PantryShortfallCalculator.stillNeeded(
            for: recipe(1, ingredients: [ingredient(1, "olive oil", 2, .tablespoons)]),
            from: &pantry,
            now: now
        )

        #expect(toBuy.isEmpty)
        #expect(pantry.first?.quantity == 450) // 480ml - 30ml (2 tbsp)
    }

    @Test func aPartialConvertibleAmountBuysTheShortfallInTheRecipesOwnUnit() throws {
        var pantry = [PantryIngredient(ingredientName: "olive oil", quantity: 10, unit: .millilitres, storageLocation: .pantry)]

        let toBuy = PantryShortfallCalculator.stillNeeded(
            for: recipe(1, ingredients: [ingredient(1, "olive oil", 2, .tablespoons)]),
            from: &pantry,
            now: now
        )

        #expect(pantry.isEmpty)
        // 2 tbsp needed (30ml), 10ml on hand -> 20ml short -> expressed back in tablespoons:
        // 20ml / 15ml per tbsp = 1.33... tbsp.
        #expect(toBuy.first?.unit == .tablespoons)
        let requiredQuantity = try #require(toBuy.first?.requiredQuantity)
        #expect(abs(requiredQuantity - (20.0 / 15.0)) < 0.0001)
    }

    /// Regression for the diagnosed "onion 200 pcs" bug: an ingredient whose quantity is
    /// flagged uncertain (Spoonacular's "servings" unit) must never be compared against the
    /// pantry — not even when the pantry happens to have a same-named `.pieces` line — since
    /// there's no trustworthy number to compare with. It goes straight onto the shopping list
    /// as its own honest, uncertain line.
    @Test func anUncertainQuantityBypassesThePantryEntirelyAndIsFlaggedOnTheShoppingList() {
        var pantry = [PantryIngredient(ingredientName: "onion", quantity: 3, unit: .pieces, storageLocation: .pantry)]

        let toBuy = PantryShortfallCalculator.stillNeeded(
            for: recipe(1, ingredients: [
                RecipeIngredient(id: 1, name: "onion", requiredQuantity: 12, unit: .pieces, quantityIsUncertain: true)
            ]),
            from: &pantry,
            now: now
        )

        // The pantry's real onion stock is untouched — an uncertain amount never deducts.
        #expect(pantry.first?.quantity == 3)
        #expect(toBuy.count == 1)
        #expect(toBuy.first?.quantityIsUncertain == true)
        #expect(toBuy.first?.ingredientName == "onion")
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
