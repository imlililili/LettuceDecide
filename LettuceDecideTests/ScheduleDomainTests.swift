import Foundation
import Testing
@testable import LettuceDecide

struct BusynessLevelTests {
    private func recipe(minutes: Int?, ingredientCount: Int) -> Recipe {
        Recipe(
            id: 1,
            title: "Test",
            readyInMinutes: minutes,
            requiredIngredients: (0..<ingredientCount).map {
                RecipeIngredient(id: $0, name: "ingredient \($0)", requiredQuantity: 1, unit: .pieces)
            }
        )
    }

    @Test func relaxedHasNoCaps() {
        #expect(BusynessLevel.relaxed.maxReadyInMinutes == nil)
        #expect(BusynessLevel.relaxed.maxRequiredIngredientCount == nil)
        #expect(BusynessLevel.relaxed.permits(recipe(minutes: 240, ingredientCount: 30)))
        #expect(BusynessLevel.relaxed.permits(recipe(minutes: nil, ingredientCount: 0)))
    }

    @Test func normalCapsTimeAtFortyMinutesOnly() {
        #expect(BusynessLevel.normal.maxReadyInMinutes == 40)
        #expect(BusynessLevel.normal.maxRequiredIngredientCount == nil)
        #expect(BusynessLevel.normal.permits(recipe(minutes: 40, ingredientCount: 20)))
        #expect(!BusynessLevel.normal.permits(recipe(minutes: 41, ingredientCount: 3)))
    }

    @Test func busyCapsTimeAtTwentyAndIngredientsAtFive() {
        #expect(BusynessLevel.busy.maxReadyInMinutes == 20)
        #expect(BusynessLevel.busy.maxRequiredIngredientCount == 5)
        #expect(BusynessLevel.busy.permits(recipe(minutes: 20, ingredientCount: 5)))
        #expect(!BusynessLevel.busy.permits(recipe(minutes: 21, ingredientCount: 5)))
        #expect(!BusynessLevel.busy.permits(recipe(minutes: 15, ingredientCount: 6)))
    }

    @Test func failsClosedWhenACappedLevelHasNoCookingTime() {
        #expect(!BusynessLevel.busy.permits(recipe(minutes: nil, ingredientCount: 3)))
        #expect(!BusynessLevel.normal.permits(recipe(minutes: nil, ingredientCount: 3)))
    }

    @Test func roundTripsThroughJSON() throws {
        let data = try JSONEncoder().encode(BusynessLevel.busy)
        #expect(try JSONDecoder().decode(BusynessLevel.self, from: data) == .busy)
    }
}

struct ScheduleEntryTests {
    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    /// 2023-11-14T00:00:00Z — a UTC day boundary, so added hours stay inside the day.
    private let midnightUTC = Date(timeIntervalSince1970: 1_699_920_000)

    @Test func pinsDateToStartOfDay() {
        let afternoon = midnightUTC.addingTimeInterval(15 * 3600)
        let entry = ScheduleEntry(date: afternoon, busyness: .normal, calendar: utc)
        #expect(entry.date == midnightUTC)
        #expect(entry.id == entry.date)
    }

    @Test func twoTimesOnTheSameDayProduceEqualIdentity() {
        let morning = midnightUTC.addingTimeInterval(7 * 3600)
        let evening = midnightUTC.addingTimeInterval(21 * 3600)
        let a = ScheduleEntry(date: morning, busyness: .relaxed, calendar: utc)
        let b = ScheduleEntry(date: evening, busyness: .busy, calendar: utc)
        #expect(a.date == b.date)
    }

    @Test func roundTripsThroughJSON() throws {
        let entry = ScheduleEntry(date: midnightUTC.addingTimeInterval(9 * 3600), busyness: .busy, calendar: utc)
        let data = try JSONEncoder().encode(entry)
        #expect(try JSONDecoder().decode(ScheduleEntry.self, from: data) == entry)
    }
}

struct ShoppingListItemTests {
    @Test func mergeKeyIgnoresCasePluralAndQuantity() {
        let a = ShoppingListItem(ingredientName: "Tomatoes", requiredQuantity: 3, unit: .pieces)
        let b = ShoppingListItem(ingredientName: "tomato", requiredQuantity: 99, unit: .pieces)
        #expect(a.mergeKey == b.mergeKey)
    }

    @Test func mergeKeyDistinguishesMeasurementGroupNotJustTheLiteralUnit() {
        let grams = ShoppingListItem(ingredientName: "flour", requiredQuantity: 200, unit: .grams)
        let cups = ShoppingListItem(ingredientName: "flour", requiredQuantity: 2, unit: .cups)
        #expect(grams.mergeKey != cups.mergeKey) // weight vs volume — never merge

        let tbsp = ShoppingListItem(ingredientName: "flour", requiredQuantity: 4, unit: .tablespoons)
        #expect(cups.mergeKey == tbsp.mergeKey) // both volume — same key, ready to merge
    }

    @Test func mergeKeyPrefersIngredientIdOverName() {
        // Different display names (as Spoonacular's own varied phrasing produces), same id.
        let garlic = ShoppingListItem(ingredientName: "garlic", requiredQuantity: 2, unit: .pieces, ingredientId: 11215)
        let garlicClove = ShoppingListItem(
            ingredientName: "garlic clove", requiredQuantity: 3, unit: .pieces, ingredientId: 11215
        )
        #expect(garlic.mergeKey == garlicClove.mergeKey)
    }

    @Test func mergeKeyFallsBackToNameWhenIdIsNil() {
        let a = ShoppingListItem(ingredientName: "onion", requiredQuantity: 1, unit: .pieces, ingredientId: nil)
        let b = ShoppingListItem(ingredientName: "onion", requiredQuantity: 2, unit: .pieces, ingredientId: nil)
        #expect(a.mergeKey == b.mergeKey)

        // A known id never collapses onto a nil-id line for the same name — they're not
        // known to be the same ingredient, only assumed to be by string.
        let withID = ShoppingListItem(ingredientName: "onion", requiredQuantity: 1, unit: .pieces, ingredientId: 11282)
        #expect(withID.mergeKey != a.mergeKey)
    }

    @Test func roundTripsThroughJSON() throws {
        let item = ShoppingListItem(
            id: UUID(),
            ingredientName: "olive oil",
            requiredQuantity: 30,
            unit: .millilitres,
            dateAdded: Date(timeIntervalSince1970: 1_700_000_000),
            ingredientId: 4053,
            quantityIsUncertain: false
        )
        let data = try JSONEncoder().encode(item)
        #expect(try JSONDecoder().decode(ShoppingListItem.self, from: data) == item)
    }

    @Test func decodesLegacyJSONWithoutIdOrUncertaintyFields() throws {
        let legacy = """
        { "id": "\(UUID().uuidString)", "ingredientName": "flour", "requiredQuantity": 200,
          "unit": "grams", "dateAdded": 700000000 }
        """.data(using: .utf8)!

        let item = try JSONDecoder().decode(ShoppingListItem.self, from: legacy)
        #expect(item.ingredientId == nil)
        #expect(item.quantityIsUncertain == false)
    }
}

/// Regression coverage for `Array<ShoppingListItem>.addMerging` — the redesigned merge rule
/// from a real user report: the same ingredient (id-matched) split across several lines by
/// unit, some of which should have merged (volume) and some of which correctly shouldn't
/// (weight/count never guess a conversion).
struct ShoppingListMergingTests {
    private func item(
        _ name: String,
        _ quantity: Double,
        _ unit: IngredientUnit,
        id: Int? = 1,
        uncertain: Bool = false
    ) -> ShoppingListItem {
        ShoppingListItem(ingredientName: name, requiredQuantity: quantity, unit: unit, ingredientId: id, quantityIsUncertain: uncertain)
    }

    @Test func mergesByIdEvenWhenNamesDiffer() {
        var list: [ShoppingListItem] = []
        list.addMerging(item("garlic", 2, .pieces, id: 11215))
        list.addMerging(item("garlic clove", 3, .pieces, id: 11215))

        #expect(list.count == 1)
        #expect(list.first?.requiredQuantity == 5)
    }

    @Test func mergesVolumeUnitsWithTheCorrectConvertedTotal() {
        var list: [ShoppingListItem] = []
        // Each addMerging rounds its running total to 2dp before the next line folds in, so
        // this is the actual step-by-step result, not the single-shot sum of all three:
        //   + 2 tbsp            -> 2 tbsp (first line, nothing to merge yet)
        //   + 1 cup  (30+240ml) -> 270ml  -> 1.125 cups -> rounds to 1.13 cups
        //   + 8 tsp  (271.2+40) -> 311.2ml -> 1.29666… cups -> rounds to 1.30 cups
        // A single-shot 2+240+40=310ml sum would read 1.29 cups instead; the ~0.4% drift from
        // rounding at each step is well inside "kitchen approximation", not "wrong".
        list.addMerging(item("olive oil", 2, .tablespoons))
        list.addMerging(item("olive oil", 1, .cups))
        list.addMerging(item("olive oil", 8, .teaspoons))

        #expect(list.count == 1)
        #expect(list.first?.unit == .cups)
        #expect(list.first?.requiredQuantity == 1.30)
    }

    @Test func neverMergesAcrossWeightVolumeOrCount() {
        var list: [ShoppingListItem] = []
        list.addMerging(item("chicken", 100, .grams))
        list.addMerging(item("chicken", 2, .pieces))
        list.addMerging(item("chicken", 1, .cups))

        #expect(list.count == 3)
        #expect(Set(list.map(\.unit)) == [.grams, .pieces, .cups])
    }

    @Test func mergingAnUncertainAmountIntoAKnownOneFlagsTheLineWithoutChangingTheNumber() {
        var list: [ShoppingListItem] = []
        list.addMerging(item("green onions", 3, .pieces, uncertain: false))
        list.addMerging(item("green onions", 4, .pieces, uncertain: true)) // e.g. from "servings"

        #expect(list.count == 1)
        #expect(list.first?.quantityIsUncertain == true)
        // The known "3" is not compounded with the untrustworthy "4" into a confident "7".
        #expect(list.first?.requiredQuantity == 3)
    }

    @Test func twoUncertainLinesForTheSameIngredientStayAsOneUncertainLine() {
        var list: [ShoppingListItem] = []
        list.addMerging(item("onion", 4, .pieces, uncertain: true))
        list.addMerging(item("onion", 12, .pieces, uncertain: true))

        #expect(list.count == 1)
        #expect(list.first?.quantityIsUncertain == true)
    }
}
