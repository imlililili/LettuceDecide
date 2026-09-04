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

    @Test func mergeKeyDistinguishesUnit() {
        let grams = ShoppingListItem(ingredientName: "flour", requiredQuantity: 200, unit: .grams)
        let cups = ShoppingListItem(ingredientName: "flour", requiredQuantity: 2, unit: .cups)
        #expect(grams.mergeKey != cups.mergeKey)
    }

    @Test func roundTripsThroughJSON() throws {
        let item = ShoppingListItem(
            id: UUID(),
            ingredientName: "olive oil",
            requiredQuantity: 30,
            unit: .millilitres,
            dateAdded: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try JSONEncoder().encode(item)
        #expect(try JSONDecoder().decode(ShoppingListItem.self, from: data) == item)
    }
}
