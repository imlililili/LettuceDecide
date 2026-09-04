import Foundation
import Testing
@testable import LettuceDecide

struct ScheduleStoreTests {
    private let anchor = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func inMemoryStoreStartsEmpty() {
        #expect(InMemoryScheduleStore().loadEntries().isEmpty)
    }

    @Test func inMemoryStoreRoundTripsSavedEntries() {
        let store = InMemoryScheduleStore()
        let entries = [
            ScheduleEntry(date: anchor, busyness: .relaxed),
            ScheduleEntry(date: anchor.addingTimeInterval(86_400), busyness: .busy),
        ]
        store.save(entries)
        #expect(store.loadEntries() == entries)
    }

    @Test func fileStoreRoundTripsThroughDisk() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("schedule-store-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("schedule.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let entries = [ScheduleEntry(date: anchor, busyness: .normal)]
        ScheduleStore(fileURL: url).save(entries)

        #expect(ScheduleStore(fileURL: url).loadEntries() == entries)
    }

    @Test func fileStoreReturnsEmptyWhenNothingSaved() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("schedule-store-tests-\(UUID().uuidString)")
            .appendingPathComponent("schedule.json")
        #expect(ScheduleStore(fileURL: url).loadEntries().isEmpty)
    }
}

struct ShoppingListStoreTests {
    @Test func inMemoryStoreStartsEmpty() {
        #expect(InMemoryShoppingListStore().loadItems().isEmpty)
    }

    @Test func inMemoryStoreRoundTripsSavedItems() {
        let store = InMemoryShoppingListStore()
        let items = [
            ShoppingListItem(ingredientName: "spinach", requiredQuantity: 200, unit: .grams),
            ShoppingListItem(ingredientName: "eggs", requiredQuantity: 6, unit: .pieces),
        ]
        store.save(items)
        #expect(store.loadItems() == items)
    }

    @Test func fileStoreRoundTripsThroughDisk() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("shopping-list-store-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("shopping-list.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let items = [ShoppingListItem(ingredientName: "butter", requiredQuantity: 250, unit: .grams)]
        ShoppingListStore(fileURL: url).save(items)

        #expect(ShoppingListStore(fileURL: url).loadItems() == items)
    }

    @Test func fileStoreReturnsEmptyWhenNothingSaved() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("shopping-list-store-tests-\(UUID().uuidString)")
            .appendingPathComponent("shopping-list.json")
        #expect(ShoppingListStore(fileURL: url).loadItems().isEmpty)
    }
}
