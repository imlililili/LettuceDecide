import Foundation

/// Coordinates fetching a recommendation from a `RecipeRepository`, keeping a short
/// history so consecutive "decide for me" taps don't repeat the same recipe.
actor RecommendationEngine {
    private let repository: RecipeRepository
    private var recentlyShownIDs: [Int] = []
    private let historyLimit: Int

    init(repository: RecipeRepository, historyLimit: Int = 5) {
        self.repository = repository
        self.historyLimit = max(historyLimit, 0)
    }

    /// Requests a new recommendation matching `preferences`, avoiding recently shown recipes.
    func recommend(matching preferences: UserPreferences) async throws -> Recipe {
        let excluded = Set(recentlyShownIDs)
        let recipe = try await repository.fetchRandomRecipe(matching: preferences, excluding: excluded)
        remember(recipe.id)
        return recipe
    }

    func resetHistory() {
        recentlyShownIDs.removeAll()
    }

    private func remember(_ id: Int) {
        recentlyShownIDs.removeAll { $0 == id }
        recentlyShownIDs.append(id)
        if recentlyShownIDs.count > historyLimit {
            recentlyShownIDs.removeFirst(recentlyShownIDs.count - historyLimit)
        }
    }
}
