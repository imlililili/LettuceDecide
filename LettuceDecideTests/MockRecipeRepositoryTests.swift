import Foundation
import Testing
@testable import LettuceDecide

struct MockRecipeRepositoryTests {
    @Test func findRecipesReturnsConfiguredCandidates() async throws {
        let repo = MockRecipeRepository()

        let candidates = try await repo.findRecipes(usingPantryNames: ["chickpeas"], matching: .default)

        #expect(candidates.count == MockRecipeRepository.sampleCandidates.count)
    }

    @Test func findRecipesRecordsTheRequest() async throws {
        let repo = MockRecipeRepository()
        var prefs = UserPreferences.default
        prefs.intolerances = [.dairy]

        _ = try await repo.findRecipes(usingPantryNames: ["milk", "flour"], matching: prefs)

        #expect(repo.lastRequestedPantryNames == ["milk", "flour"])
        #expect(repo.lastRequestedPreferences == prefs)
    }

    @Test func findRecipesThrowsTheConfiguredError() async {
        let repo = MockRecipeRepository(errorToThrow: RecipeRepositoryError.noResultsFound)

        await #expect(throws: RecipeRepositoryError.self) {
            _ = try await repo.findRecipes(usingPantryNames: [], matching: .default)
        }
    }
}
