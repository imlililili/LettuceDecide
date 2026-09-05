import Foundation
import Testing
@testable import LettuceDecide

struct CachingRecipeRepositoryTests {
    // MARK: - Test doubles

    private final class StubRecipeRepository: RecipeRepository {
        var result: Result<[PantryRecipeCandidate], Error>
        private(set) var callCount = 0

        init(result: Result<[PantryRecipeCandidate], Error>) {
            self.result = result
        }

        func findRecipes(
            usingPantryNames pantryIngredientNames: [String],
            matching preferences: UserPreferences
        ) async throws -> [PantryRecipeCandidate] {
            callCount += 1
            return try result.get()
        }
    }

    private final class SpyCache: RecipeCacheStoring {
        var stored: [String: [PantryRecipeCandidate]]
        private(set) var loadCount = 0
        private(set) var saveCount = 0

        init(stored: [String: [PantryRecipeCandidate]] = [:]) {
            self.stored = stored
        }

        func loadCachedCandidates(forKey key: String) -> [PantryRecipeCandidate]? {
            loadCount += 1
            return stored[key]
        }

        func save(_ candidates: [PantryRecipeCandidate], forKey key: String) {
            saveCount += 1
            stored[key] = candidates
        }
    }

    private func candidate(_ id: Int) -> PantryRecipeCandidate {
        PantryRecipeCandidate(
            recipe: Recipe(id: id, title: "Recipe \(id)"),
            usedIngredientNames: [],
            missedIngredients: []
        )
    }

    private func networkError() -> RecipeRepositoryError {
        .network(URLError(.notConnectedToInternet))
    }

    // MARK: - Falling back to the cache

    @Test func servesCache_whenNetworkFailsAndAnEntryExists() async throws {
        let key = CachingRecipeRepository.cacheKey(names: ["onion"], preferences: .default)
        let cache = SpyCache(stored: [key: [candidate(1), candidate(2)]])
        let sut = CachingRecipeRepository(
            wrapping: StubRecipeRepository(result: .failure(networkError())),
            cache: cache
        )

        let result = try await sut.findRecipes(usingPantryNames: ["onion"], matching: .default)

        #expect(result.map(\.recipe.id) == [1, 2])
        let allFromCache = result.allSatisfy(\.isFromCache)
        #expect(allFromCache)
    }

    @Test func rethrows_whenNetworkFailsAndCacheIsEmpty() async {
        let sut = CachingRecipeRepository(
            wrapping: StubRecipeRepository(result: .failure(networkError())),
            cache: SpyCache()
        )

        await #expect(throws: RecipeRepositoryError.self) {
            _ = try await sut.findRecipes(usingPantryNames: ["onion"], matching: .default)
        }
    }

    @Test func nonNetworkError_isRethrownWithoutConsultingTheCache() async {
        let key = CachingRecipeRepository.cacheKey(names: ["onion"], preferences: .default)
        let cache = SpyCache(stored: [key: [candidate(1)]])
        let sut = CachingRecipeRepository(
            wrapping: StubRecipeRepository(result: .failure(RecipeRepositoryError.missingAPIKey)),
            cache: cache
        )

        await #expect(throws: RecipeRepositoryError.self) {
            _ = try await sut.findRecipes(usingPantryNames: ["onion"], matching: .default)
        }
        #expect(cache.loadCount == 0)
    }

    // MARK: - Populating the cache

    @Test func fetchesLive_andWritesToCache_onSuccess() async throws {
        let cache = SpyCache()
        let stub = StubRecipeRepository(result: .success([candidate(7)]))
        let sut = CachingRecipeRepository(wrapping: stub, cache: cache)

        let fresh = try await sut.findRecipes(usingPantryNames: ["rice"], matching: .default)

        #expect(fresh.map(\.recipe.id) == [7])
        let noneFromCache = fresh.allSatisfy { !$0.isFromCache }
        #expect(noneFromCache)
        #expect(cache.saveCount == 1)

        // The network then drops — the just-cached result comes back, flagged as stale.
        stub.result = .failure(networkError())
        let cached = try await sut.findRecipes(usingPantryNames: ["rice"], matching: .default)

        #expect(cached.map(\.recipe.id) == [7])
        let allFromCache = cached.allSatisfy(\.isFromCache)
        #expect(allFromCache)
    }

    @Test func emptyResults_areNotCached() async throws {
        let cache = SpyCache()
        let stub = StubRecipeRepository(result: .success([]))
        let sut = CachingRecipeRepository(wrapping: stub, cache: cache)

        _ = try await sut.findRecipes(usingPantryNames: ["x"], matching: .default)
        #expect(cache.saveCount == 0)

        // Nothing was stored, so an offline retry still surfaces the error.
        stub.result = .failure(networkError())
        await #expect(throws: RecipeRepositoryError.self) {
            _ = try await sut.findRecipes(usingPantryNames: ["x"], matching: .default)
        }
    }

    // MARK: - Cache key

    @Test func cacheKey_isOrderAndPluralInsensitive() {
        let a = CachingRecipeRepository.cacheKey(names: ["Onion", "rice"], preferences: .default)
        let b = CachingRecipeRepository.cacheKey(names: ["rice", "onions"], preferences: .default)
        #expect(a == b)
    }

    @Test func cacheKey_changesWithDietaryPreferences() {
        let base = CachingRecipeRepository.cacheKey(names: ["onion"], preferences: .default)

        var withIntolerance = UserPreferences.default
        withIntolerance.intolerances = [.dairy]
        #expect(CachingRecipeRepository.cacheKey(names: ["onion"], preferences: withIntolerance) != base)

        var withDiet = UserPreferences.default
        withDiet.diet = .vegan
        #expect(CachingRecipeRepository.cacheKey(names: ["onion"], preferences: withDiet) != base)
    }
}
