import Foundation

/// In-memory repository used by previews, unit tests, and as a fallback when no API key is configured.
final class MockRecipeRepository: RecipeRepository {
    var fixedRecipes: [Recipe]
    var errorToThrow: Error?
    private(set) var lastRequestedPreferences: UserPreferences?

    init(fixedRecipes: [Recipe] = MockRecipeRepository.sampleRecipes, errorToThrow: Error? = nil) {
        self.fixedRecipes = fixedRecipes
        self.errorToThrow = errorToThrow
    }

    func fetchRandomRecipe(matching preferences: UserPreferences, excluding excludedIDs: Set<Int>) async throws -> Recipe {
        lastRequestedPreferences = preferences
        if let errorToThrow { throw errorToThrow }

        let candidates = fixedRecipes.filter { !excludedIDs.contains($0.id) }
        guard let pick = candidates.randomElement() ?? fixedRecipes.first else {
            throw RecipeRepositoryError.noResultsFound
        }
        return pick
    }

    static let sampleRecipes: [Recipe] = [
        Recipe(
            id: 1,
            title: "Lemon Garlic Roasted Salmon",
            imageURL: nil,
            readyInMinutes: 25,
            servings: 2,
            sourceURL: URL(string: "https://example.com/salmon"),
            summary: "A bright, weeknight-friendly salmon with lemon and garlic.",
            healthScore: 92,
            diets: ["pescetarian", "gluten free"]
        ),
        Recipe(
            id: 2,
            title: "Chickpea and Spinach Curry",
            imageURL: nil,
            readyInMinutes: 35,
            servings: 4,
            sourceURL: URL(string: "https://example.com/curry"),
            summary: "A cozy, protein-packed curry that comes together in one pot.",
            healthScore: 88,
            diets: ["vegan", "vegetarian", "dairy free"]
        ),
        Recipe(
            id: 3,
            title: "Classic Margherita Pizza",
            imageURL: nil,
            readyInMinutes: 40,
            servings: 4,
            sourceURL: URL(string: "https://example.com/pizza"),
            summary: "Simple, fresh, and always a crowd-pleaser.",
            healthScore: 55,
            diets: ["vegetarian"]
        ),
    ]
}
