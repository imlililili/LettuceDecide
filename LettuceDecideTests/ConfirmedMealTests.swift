import Combine
import Foundation
import Testing
@testable import LettuceDecide

struct ConfirmedMealTests {
    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private let noonOnAMonday = Date(timeIntervalSince1970: 1_699_876_800) // 2023-11-13T12:00:00Z

    @Test func idIsNormalisedToTheStartOfTheDay() {
        let meal = ConfirmedMeal(
            date: noonOnAMonday,
            recipe: Recipe(id: 1, title: "Curry"),
            calendar: utc
        )

        #expect(meal.id == utc.startOfDay(for: noonOnAMonday))
        #expect(meal.date == meal.id)
    }

    @Test func roundTripsThroughJSON() throws {
        let meal = ConfirmedMeal(date: noonOnAMonday, recipe: Recipe(id: 1, title: "Curry"), calendar: utc)
        let data = try JSONEncoder().encode(meal)
        #expect(try JSONDecoder().decode(ConfirmedMeal.self, from: data) == meal)
    }
}

struct ConfirmedMealStoreTests {
    private let anchor = Date(timeIntervalSince1970: 1_700_000_000)

    private func meal(_ recipeID: Int, on date: Date) -> ConfirmedMeal {
        ConfirmedMeal(date: date, recipe: Recipe(id: recipeID, title: "Recipe \(recipeID)"))
    }

    @Test func inMemoryStoreStartsEmpty() {
        #expect(InMemoryConfirmedMealStore().loadConfirmedMeals().isEmpty)
    }

    @Test func confirmingADayWithNothingYetConfirmedAddsIt() {
        let store = InMemoryConfirmedMealStore()

        store.confirm(meal(1, on: anchor))

        #expect(store.loadConfirmedMeals().map(\.recipe.id) == [1])
    }

    @Test func confirmingTheSameDayAgainReplacesItRatherThanAddingASecondEntry() {
        let store = InMemoryConfirmedMealStore(initial: [meal(1, on: anchor)])

        store.confirm(meal(2, on: anchor))

        let all = store.loadConfirmedMeals()
        #expect(all.count == 1)
        #expect(all.first?.recipe.id == 2)
    }

    @Test func confirmingADifferentDayAddsASecondEntry() {
        let store = InMemoryConfirmedMealStore(initial: [meal(1, on: anchor)])

        store.confirm(meal(2, on: anchor.addingTimeInterval(86_400)))

        #expect(Set(store.loadConfirmedMeals().map(\.recipe.id)) == [1, 2])
    }

    @Test func removingAConfirmedMealDropsOnlyThatDay() {
        let store = InMemoryConfirmedMealStore(initial: [
            meal(1, on: anchor),
            meal(2, on: anchor.addingTimeInterval(86_400)),
        ])

        store.removeConfirmedMeal(for: anchor)

        #expect(store.loadConfirmedMeals().map(\.recipe.id) == [2])
    }

    @Test func removingADayWithNothingConfirmedIsANoOp() {
        let store = InMemoryConfirmedMealStore(initial: [meal(1, on: anchor)])

        store.removeConfirmedMeal(for: anchor.addingTimeInterval(86_400))

        #expect(store.loadConfirmedMeals().map(\.recipe.id) == [1])
    }

    @Test func fileStoreRoundTripsThroughDisk() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("confirmed-meal-store-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("confirmed-meals.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        ConfirmedMealStore(fileURL: url).confirm(meal(1, on: anchor))

        #expect(ConfirmedMealStore(fileURL: url).loadConfirmedMeals().map(\.recipe.id) == [1])
    }

    @Test func fileStoreReturnsEmptyWhenNothingSaved() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("confirmed-meal-store-tests-\(UUID().uuidString)")
            .appendingPathComponent("confirmed-meals.json")
        #expect(ConfirmedMealStore(fileURL: url).loadConfirmedMeals().isEmpty)
    }

    // MARK: - changes publisher (same contract as PantryStoring.changes)

    @Test func inMemoryStoreAnnouncesAChangeAfterConfirm() {
        let store = InMemoryConfirmedMealStore()
        var changeCount = 0
        let cancellable = store.changes.sink { changeCount += 1 }

        store.confirm(meal(1, on: anchor))

        #expect(changeCount == 1)
        withExtendedLifetime(cancellable) {}
    }

    @Test func inMemoryStoreAnnouncesAChangeAfterRemoval() {
        let store = InMemoryConfirmedMealStore(initial: [meal(1, on: anchor)])
        var changeCount = 0
        let cancellable = store.changes.sink { changeCount += 1 }

        store.removeConfirmedMeal(for: anchor)

        #expect(changeCount == 1)
        withExtendedLifetime(cancellable) {}
    }

    @Test func fileStoreAnnouncesAChangeAfterConfirmAndRemoval() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("confirmed-meal-store-tests-\(UUID().uuidString)")
            .appendingPathComponent("confirmed-meals.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = ConfirmedMealStore(fileURL: url)
        var changeCount = 0
        let cancellable = store.changes.sink { changeCount += 1 }

        store.confirm(meal(1, on: anchor))
        store.removeConfirmedMeal(for: anchor)

        #expect(changeCount == 2)
        withExtendedLifetime(cancellable) {}
    }
}
