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

    @Test func recognisesTheBareCAbbreviationForCups() {
        #expect(IngredientUnit(spoonacularUnit: "c") == .cups)
        #expect(IngredientUnit(spoonacularUnit: "C") == .cups)
    }

    @Test func measurementGroupsSeparateWeightVolumeAndCount() {
        #expect(IngredientUnit.grams.measurementGroup == .weight)
        #expect(IngredientUnit.pieces.measurementGroup == .count)
        #expect(IngredientUnit.millilitres.measurementGroup == .volume)
        #expect(IngredientUnit.cups.measurementGroup == .volume)
        #expect(IngredientUnit.tablespoons.measurementGroup == .volume)
        #expect(IngredientUnit.teaspoons.measurementGroup == .volume)
    }

    /// Live-diagnosed: "gr" is a real Spoonacular grams abbreviation that wasn't recognised,
    /// silently falling back to `.pieces` — directly implicated in the reported
    /// "potatoes 200 pcs" (the source line was "200 gr", i.e. 200 grams).
    @Test func recognisesTheGrAbbreviationForGrams() {
        #expect(IngredientUnit(spoonacularUnit: "gr") == .grams)
        #expect(IngredientUnit(spoonacularUnit: "GR") == .grams)
    }
}

struct IngredientUnitRescalingTests {
    /// Live-diagnosed: "kg"/"kilogram(s)" isn't a string this app's unit set can name
    /// directly (there's no `.kilograms` case), and without rescaling the amount it fell
    /// through to `.pieces` unchanged — a "0.5 kg" ingredient silently became "0.5 pieces".
    @Test func kilogramVariantsRescaleToGrams() {
        for raw in ["kg", "Kg", "kilogram", "kilograms"] {
            let result = IngredientUnit.rescaledAmount(0.5, rawUnit: raw)
            #expect(result?.unit == .grams, "unit for \(raw)")
            #expect(result?.amount == 500, "amount for \(raw)")
        }
    }

    @Test func returnsNilForUnitsThatDoNotNeedRescaling() {
        #expect(IngredientUnit.rescaledAmount(200, rawUnit: "gr") == nil) // "gr" is already gram-scaled
        #expect(IngredientUnit.rescaledAmount(2, rawUnit: "cups") == nil)
        #expect(IngredientUnit.rescaledAmount(3, rawUnit: "pieces") == nil)
    }
}

struct VolumeConversionTests {
    @Test func convertsEachVolumeUnitToMillilitres() {
        #expect(IngredientUnit.VolumeConversion.millilitres(for: 2, unit: .millilitres) == 2)
        #expect(IngredientUnit.VolumeConversion.millilitres(for: 1, unit: .cups) == 240)
        #expect(IngredientUnit.VolumeConversion.millilitres(for: 1, unit: .tablespoons) == 15)
        #expect(IngredientUnit.VolumeConversion.millilitres(for: 1, unit: .teaspoons) == 5)
    }

    @Test func returnsNilForNonVolumeUnits() {
        #expect(IngredientUnit.VolumeConversion.millilitres(for: 1, unit: .grams) == nil)
        #expect(IngredientUnit.VolumeConversion.millilitres(for: 1, unit: .pieces) == nil)
    }

    @Test func displayFormPicksCupsOnceThereIsAtLeastAFullCup() {
        let (quantity, unit) = IngredientUnit.VolumeConversion.displayForm(millilitres: 480)
        #expect(unit == .cups)
        #expect(quantity == 2)
    }

    @Test func displayFormPicksTablespoonsBelowACupButAtLeastATablespoon() {
        let (quantity, unit) = IngredientUnit.VolumeConversion.displayForm(millilitres: 30)
        #expect(unit == .tablespoons)
        #expect(quantity == 2)
    }

    @Test func displayFormPicksTeaspoonsBelowATablespoon() {
        let (quantity, unit) = IngredientUnit.VolumeConversion.displayForm(millilitres: 10)
        #expect(unit == .teaspoons)
        #expect(quantity == 2)
    }

    @Test func displayFormRoundsToTwoDecimalPlaces() {
        // 100ml in tablespoons = 6.6666... -> must not print as 6.66666667.
        let (quantity, unit) = IngredientUnit.VolumeConversion.displayForm(millilitres: 100)
        #expect(unit == .tablespoons)
        #expect(quantity == 6.67)
    }
}
