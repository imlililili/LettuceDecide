import Foundation
import Testing
@testable import LettuceDecide

struct PantryStoreTests {
    @Test func inMemoryStoreStartsEmpty() {
        #expect(InMemoryPantryStore().load().isEmpty)
    }

    @Test func inMemoryStoreRoundTripsSavedInventory() {
        let store = InMemoryPantryStore()
        let items = [
            PantryIngredient(ingredientName: "spinach", quantity: 200, unit: .grams, storageLocation: .fridge),
            PantryIngredient(ingredientName: "rice", quantity: 1000, unit: .grams, storageLocation: .pantry),
        ]
        store.save(items)
        #expect(store.load() == items)
    }

    @Test func fileStoreRoundTripsThroughDisk() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pantry-store-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("pantry.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let items = [
            PantryIngredient(ingredientName: "butter", quantity: 250, unit: .grams, storageLocation: .fridge)
        ]
        PantryStore(fileURL: url).save(items)

        #expect(PantryStore(fileURL: url).load() == items)
    }

    @Test func fileStoreReturnsEmptyWhenNothingSaved() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pantry-store-tests-\(UUID().uuidString)")
            .appendingPathComponent("pantry.json")
        #expect(PantryStore(fileURL: url).load().isEmpty)
    }
}
