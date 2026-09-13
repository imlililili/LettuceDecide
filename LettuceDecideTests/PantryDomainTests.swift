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
    @Test func isSameStockIgnoresQuantityCaseAndPluralWhenIdsAreNil() {
        let a = PantryIngredient(ingredientName: "Tomatoes", quantity: 2, unit: .pieces, storageLocation: .fridge)
        let b = PantryIngredient(ingredientName: "tomato", quantity: 99, unit: .pieces, storageLocation: .fridge)
        #expect(a.isSameStock(as: b))
    }

    @Test func isSameStockDistinguishesLocation() {
        let a = PantryIngredient(ingredientName: "peas", quantity: 1, unit: .grams, storageLocation: .fridge)
        let b = PantryIngredient(ingredientName: "peas", quantity: 1, unit: .grams, storageLocation: .freezer)
        #expect(!a.isSameStock(as: b))
    }

    @Test func isSameStockDistinguishesUnit() {
        let a = PantryIngredient(ingredientName: "flour", quantity: 200, unit: .grams, storageLocation: .pantry)
        let b = PantryIngredient(ingredientName: "flour", quantity: 2, unit: .cups, storageLocation: .pantry)
        #expect(!a.isSameStock(as: b)) // unlike the shopping list, pantry never converts units
    }

    /// Same rule shape as `ShoppingListItem.isSamePurchase(as:)`: matching on id OR name,
    /// either sufficient — not "id when present, else name" — so a pantry line originating
    /// from a purchase (carrying an id) still recognises a hand-typed line with no id at all,
    /// and a known id present on both sides matches even if the names happen to differ.
    @Test func isSameStockMatchesOnEitherIdOrName() {
        let byName = PantryIngredient(ingredientName: "onion", quantity: 1, unit: .pieces, storageLocation: .pantry, ingredientId: nil)
        let byNameAgain = PantryIngredient(ingredientName: "onion", quantity: 2, unit: .pieces, storageLocation: .pantry, ingredientId: 11282)
        #expect(byName.isSameStock(as: byNameAgain)) // known id still matches a nil-id line by name

        let spring = PantryIngredient(ingredientName: "spring onion", quantity: 1, unit: .pieces, storageLocation: .pantry, ingredientId: 11291)
        let green = PantryIngredient(ingredientName: "green onions", quantity: 1, unit: .pieces, storageLocation: .pantry, ingredientId: 11291)
        #expect(spring.isSameStock(as: green)) // same id, different wording
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

struct NormalizedForPantryStorageTests {
    @Test func convertsEachVolumeUnitToMillilitres() {
        #expect(IngredientUnit.normalizedForPantryStorage(quantity: 2, unit: .cups).quantity == 480)
        #expect(IngredientUnit.normalizedForPantryStorage(quantity: 2, unit: .cups).unit == .millilitres)
        #expect(IngredientUnit.normalizedForPantryStorage(quantity: 3, unit: .tablespoons).quantity == 45)
        #expect(IngredientUnit.normalizedForPantryStorage(quantity: 4, unit: .teaspoons).quantity == 20)
    }

    @Test func millilitresPassThroughUnchanged() {
        let result = IngredientUnit.normalizedForPantryStorage(quantity: 300, unit: .millilitres)
        #expect(result.quantity == 300)
        #expect(result.unit == .millilitres)
    }

    @Test func leavesWeightAndCountUnchanged() {
        let grams = IngredientUnit.normalizedForPantryStorage(quantity: 200, unit: .grams)
        #expect(grams.quantity == 200)
        #expect(grams.unit == .grams)

        let pieces = IngredientUnit.normalizedForPantryStorage(quantity: 3, unit: .pieces)
        #expect(pieces.quantity == 3)
        #expect(pieces.unit == .pieces)
    }
}

/// The shared helper behind the cooking-deduction volume-conversion fix — every "can these
/// two quantities be compared" decision (`UpdateInventoryAfterCookingUseCase`,
/// `PantryShortfallCalculator`, the Recipe Detail checklist) goes through this one function.
struct IngredientUnitConvertTests {
    @Test func sameUnitReturnsTheQuantityUnchanged() {
        #expect(IngredientUnit.convert(200, from: .grams, to: .grams) == 200)
        #expect(IngredientUnit.convert(2, from: .cups, to: .cups) == 2)
    }

    @Test func convertsWithinTheVolumeGroup() {
        // 2 tbsp = 30ml -> in millilitres.
        #expect(IngredientUnit.convert(2, from: .tablespoons, to: .millilitres) == 30)
        // 480ml -> in cups (2 cups).
        #expect(IngredientUnit.convert(480, from: .millilitres, to: .cups) == 2)
        // 1 cup -> in teaspoons (240ml / 5ml per tsp = 48 tsp).
        #expect(IngredientUnit.convert(1, from: .cups, to: .teaspoons) == 48)
    }

    @Test func returnsNilAcrossMeasurementGroups() {
        #expect(IngredientUnit.convert(200, from: .grams, to: .pieces) == nil)
        #expect(IngredientUnit.convert(2, from: .pieces, to: .millilitres) == nil)
        #expect(IngredientUnit.convert(1, from: .cups, to: .grams) == nil)
        #expect(IngredientUnit.convert(100, from: .grams, to: .tablespoons) == nil)
    }
}
