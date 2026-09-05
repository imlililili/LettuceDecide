import Foundation
import Testing
@testable import LettuceDecide

struct RecipeCacheStoreTests {
    private func candidate(_ id: Int) -> PantryRecipeCandidate {
        PantryRecipeCandidate(
            recipe: Recipe(id: id, title: "Recipe \(id)", readyInMinutes: 20),
            usedIngredientNames: ["onion"],
            missedIngredients: [RecipeIngredient(id: 1, name: "garlic", requiredQuantity: 2, unit: .pieces)]
        )
    }

    @Test func inMemoryStoreReturnsNilForAnUnknownKey() {
        #expect(InMemoryRecipeCacheStore().loadCachedCandidates(forKey: "nope") == nil)
    }

    @Test func inMemoryStoreRoundTripsSavedCandidates() {
        let store = InMemoryRecipeCacheStore()
        store.save([candidate(1), candidate(2)], forKey: "q")
        #expect(store.loadCachedCandidates(forKey: "q")?.map(\.recipe.id) == [1, 2])
    }

    @Test func fileStoreRoundTripsThroughDisk() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("recipe-cache-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("recipe-cache.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        RecipeCacheStore(fileURL: url).save([candidate(3), candidate(4)], forKey: "onion|none||-")

        let reloaded = RecipeCacheStore(fileURL: url).loadCachedCandidates(forKey: "onion|none||-")
        #expect(reloaded?.map(\.recipe.id) == [3, 4])
        let noneFlaggedStale = reloaded?.allSatisfy { !$0.isFromCache }
        #expect(noneFlaggedStale == true)
    }

    @Test func fileStoreKeepsSeparateEntriesPerKey() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("recipe-cache-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("recipe-cache.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let store = RecipeCacheStore(fileURL: url)
        store.save([candidate(1)], forKey: "a")
        store.save([candidate(2)], forKey: "b")

        let reopened = RecipeCacheStore(fileURL: url)
        #expect(reopened.loadCachedCandidates(forKey: "a")?.map(\.recipe.id) == [1])
        #expect(reopened.loadCachedCandidates(forKey: "b")?.map(\.recipe.id) == [2])
    }

    @Test func fileStoreReturnsNilWhenNothingSaved() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("recipe-cache-tests-\(UUID().uuidString)")
            .appendingPathComponent("recipe-cache.json")
        #expect(RecipeCacheStore(fileURL: url).loadCachedCandidates(forKey: "anything") == nil)
    }
}
