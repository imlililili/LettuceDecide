import Testing
@testable import LettuceDecide

struct RecommendationEngineTests {
    @Test func recommendReturnsARecipeFromTheRepository() async throws {
        let mock = MockRecipeRepository(fixedRecipes: [MockRecipeRepository.sampleRecipes[0]])
        let engine = RecommendationEngine(repository: mock)

        let recipe = try await engine.recommend(matching: .default)

        #expect(recipe.id == MockRecipeRepository.sampleRecipes[0].id)
    }

    @Test func recommendPassesPreferencesThroughToTheRepository() async throws {
        let mock = MockRecipeRepository()
        let engine = RecommendationEngine(repository: mock)
        var prefs = UserPreferences.default
        prefs.intolerances = [.gluten]
        prefs.diet = .vegan

        _ = try await engine.recommend(matching: prefs)

        #expect(mock.lastRequestedPreferences == prefs)
    }

    @Test func recommendAvoidsImmediatelyRepeatingTheLastRecipeWhenAlternativesExist() async throws {
        let recipes = MockRecipeRepository.sampleRecipes
        let mock = MockRecipeRepository(fixedRecipes: recipes)
        let engine = RecommendationEngine(repository: mock, historyLimit: recipes.count - 1)

        var seen: [Int] = []
        for _ in 0..<10 {
            let recipe = try await engine.recommend(matching: .default)
            seen.append(recipe.id)
        }

        // With history covering all-but-one recipe, no two consecutive picks should match.
        for pair in zip(seen, seen.dropFirst()) {
            #expect(pair.0 != pair.1)
        }
    }

    @Test func recommendPropagatesRepositoryErrors() async {
        let mock = MockRecipeRepository(errorToThrow: RecipeRepositoryError.noResultsFound)
        let engine = RecommendationEngine(repository: mock)

        await #expect(throws: RecipeRepositoryError.self) {
            _ = try await engine.recommend(matching: .default)
        }
    }

    @Test func resetHistoryClearsExclusions() async throws {
        let mock = MockRecipeRepository(fixedRecipes: [MockRecipeRepository.sampleRecipes[0]])
        let engine = RecommendationEngine(repository: mock, historyLimit: 5)

        _ = try await engine.recommend(matching: .default)
        await engine.resetHistory()

        // Should not throw even though the only recipe was already "shown."
        let recipe = try await engine.recommend(matching: .default)
        #expect(recipe.id == MockRecipeRepository.sampleRecipes[0].id)
    }
}
