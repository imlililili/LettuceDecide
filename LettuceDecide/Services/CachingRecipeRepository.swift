import Foundation

/// A `RecipeRepository` decorator that keeps the last successful search per query and serves
/// it back when — and only when — the network is unreachable.
///
/// Business rules:
/// - A fresh fetch that succeeds is returned as-is and written to the cache (its candidates
///   keep `isFromCache == false`).
/// - Only a genuine network failure (`RecipeRepositoryError.network`, which wraps timeouts
///   and connectivity errors) falls back to the cache. `missingAPIKey`, `invalidResponse`,
///   `requestFailed` and `noResultsFound` are *not* connectivity problems — pretending we
///   have data would hide a real misconfiguration, so those propagate untouched and the
///   cache is not even consulted.
/// - Empty and failed results are never cached — there is nothing worth serving offline.
/// - Cache hits come back with every candidate's `isFromCache == true` so the UI can be
///   honest that the data may be stale — the same "don't dress up unverified data as fact"
///   principle as the allergen safety rule.
final class CachingRecipeRepository: RecipeRepository {
    private let wrapped: RecipeRepository
    private let cache: RecipeCacheStoring

    init(wrapping wrapped: RecipeRepository, cache: RecipeCacheStoring) {
        self.wrapped = wrapped
        self.cache = cache
    }

    func findRecipes(
        usingPantryNames pantryIngredientNames: [String],
        matching preferences: UserPreferences
    ) async throws -> [PantryRecipeCandidate] {
        let key = Self.cacheKey(names: pantryIngredientNames, preferences: preferences)

        do {
            let fresh = try await wrapped.findRecipes(
                usingPantryNames: pantryIngredientNames,
                matching: preferences
            )
            if !fresh.isEmpty {
                cache.save(fresh, forKey: key)
            }
            return fresh
        } catch let error as RecipeRepositoryError where Self.isNetworkFailure(error) {
            guard let cached = cache.loadCachedCandidates(forKey: key) else {
                throw error
            }
            return cached.map { candidate in
                var candidate = candidate
                candidate.isFromCache = true
                return candidate
            }
        }
    }

    /// Whether `error` means "couldn't reach the server", as opposed to a configuration or
    /// protocol problem that a cache must not paper over.
    static func isNetworkFailure(_ error: RecipeRepositoryError) -> Bool {
        switch error {
        case .network:
            return true
        case .missingAPIKey, .invalidResponse, .requestFailed, .noResultsFound:
            return false
        }
    }

    /// A stable key for "the same query": normalised pantry names plus every dietary setting
    /// that changes the request. Order-independent, so the same pantry in a different order
    /// still hits.
    static func cacheKey(names: [String], preferences: UserPreferences) -> String {
        let normalizedNames = Set(names.map { $0.normalizedIngredientName }).sorted()
        let intolerances = preferences.intolerances.map(\.rawValue).sorted().joined(separator: ",")
        let excluded = preferences.excludedIngredients.map { $0.lowercased() }.sorted().joined(separator: ",")
        let maxTime = preferences.maxReadyTimeMinutes.map(String.init) ?? "-"
        return [
            normalizedNames.joined(separator: ","),
            preferences.diet.rawValue,
            intolerances,
            excluded,
            maxTime,
        ].joined(separator: "|")
    }
}
