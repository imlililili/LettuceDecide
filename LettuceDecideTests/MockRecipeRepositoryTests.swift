import Testing
@testable import LettuceDecide

struct MockRecipeRepositoryTests {
    @Test func fetchExcludesRequestedIDsWhenAlternativesExist() async throws {
        let repo = MockRecipeRepository()
        let excluded = Set(MockRecipeRepository.sampleRecipes.dropLast().map(\.id))

        let recipe = try await repo.fetchRandomRecipe(matching: .default, excluding: excluded)

        #expect(recipe.id == MockRecipeRepository.sampleRecipes.last?.id)
    }

    @Test func fetchFallsBackToFirstRecipeWhenAllAreExcluded() async throws {
        let repo = MockRecipeRepository()
        let allIDs = Set(MockRecipeRepository.sampleRecipes.map(\.id))

        let recipe = try await repo.fetchRandomRecipe(matching: .default, excluding: allIDs)

        #expect(recipe.id == MockRecipeRepository.sampleRecipes.first?.id)
    }

    @Test func fetchThrowsWhenNoRecipesAreConfigured() async {
        let repo = MockRecipeRepository(fixedRecipes: [])

        await #expect(throws: RecipeRepositoryError.self) {
            _ = try await repo.fetchRandomRecipe(matching: .default, excluding: [])
        }
    }

    @Test func fetchRecordsTheLastRequestedPreferences() async throws {
        let repo = MockRecipeRepository()
        var prefs = UserPreferences.default
        prefs.excludedIngredients = ["cilantro"]

        _ = try await repo.fetchRandomRecipe(matching: prefs, excluding: [])

        #expect(repo.lastRequestedPreferences == prefs)
    }
}
