import Foundation
import Testing
@testable import LettuceDecide

struct ExpiryStatusTests {
    private let now = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))

    @Test func noExpiryDateIsFresh() {
        #expect(ExpiryStatus(expiryDate: nil, asOf: now) == .fresh)
    }

    @Test func dateInThePastIsExpired() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        #expect(ExpiryStatus(expiryDate: yesterday, asOf: now) == .expired)
    }

    @Test func todayIsExpiringSoonWithZeroDaysRemaining() {
        #expect(ExpiryStatus(expiryDate: now, asOf: now) == .expiringSoon(daysRemaining: 0))
    }

    @Test func withinThresholdIsExpiringSoon() {
        let inThreeDays = Calendar.current.date(byAdding: .day, value: 3, to: now)!
        #expect(ExpiryStatus(expiryDate: inThreeDays, asOf: now) == .expiringSoon(daysRemaining: 3))
    }

    @Test func justPastThresholdIsFresh() {
        let inFourDays = Calendar.current.date(byAdding: .day, value: 4, to: now)!
        #expect(ExpiryStatus(expiryDate: inFourDays, asOf: now) == .fresh)
    }
}

struct IngredientNameNormalizationTests {
    @Test func lowercasesAndTrims() {
        #expect("  Chicken Breast  ".normalizedIngredientName == "chicken breast")
    }

    @Test func stripsSimplePlural() {
        #expect("eggs".normalizedIngredientName == "egg")
    }

    @Test func stripsEsPlural() {
        #expect("tomatoes".normalizedIngredientName == "tomato")
    }

    @Test func stripsIesPlural() {
        #expect("berries".normalizedIngredientName == "berry")
    }
}

struct PantryIngredientTests {
    @Test func mergeKeyIgnoresQuantityCaseAndPlural() {
        let a = PantryIngredient(ingredientName: "Tomatoes", quantity: 2, unit: .pieces, storageLocation: .fridge)
        let b = PantryIngredient(ingredientName: "tomato", quantity: 99, unit: .pieces, storageLocation: .fridge)
        #expect(a.mergeKey == b.mergeKey)
    }

    @Test func mergeKeyDistinguishesLocation() {
        let a = PantryIngredient(ingredientName: "peas", quantity: 1, unit: .grams, storageLocation: .fridge)
        let b = PantryIngredient(ingredientName: "peas", quantity: 1, unit: .grams, storageLocation: .freezer)
        #expect(a.mergeKey != b.mergeKey)
    }

    @Test func roundTripsThroughJSON() throws {
        let ingredient = PantryIngredient(
            ingredientName: "Greek yoghurt",
            quantity: 500,
            unit: .grams,
            storageLocation: .fridge,
            expiryDate: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try JSONEncoder().encode(ingredient)
        let decoded = try JSONDecoder().decode(PantryIngredient.self, from: data)
        #expect(decoded == ingredient)
    }
}

struct IngredientUnitTests {
    @Test func parsesCommonSpoonacularUnits() {
        #expect(IngredientUnit(spoonacularUnit: "grams") == .grams)
        #expect(IngredientUnit(spoonacularUnit: "Cup") == .cups)
        #expect(IngredientUnit(spoonacularUnit: "tablespoons") == .tablespoons)
        #expect(IngredientUnit(spoonacularUnit: "") == .pieces)
    }

    @Test func returnsNilForUnknownUnit() {
        #expect(IngredientUnit(spoonacularUnit: "clove") == nil)
    }
}
