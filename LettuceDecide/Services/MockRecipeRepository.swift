import Foundation

/// In-memory repository used by previews, unit tests, and as a fallback when no API key is configured.
final class MockRecipeRepository: RecipeRepository {
    var candidates: [PantryRecipeCandidate]
    var errorToThrow: Error?
    private(set) var lastRequestedPantryNames: [String]?
    private(set) var lastRequestedPreferences: UserPreferences?

    init(
        candidates: [PantryRecipeCandidate] = MockRecipeRepository.sampleCandidates,
        errorToThrow: Error? = nil
    ) {
        self.candidates = candidates
        self.errorToThrow = errorToThrow
    }

    func findRecipes(
        usingPantryNames pantryIngredientNames: [String],
        matching preferences: UserPreferences
    ) async throws -> [PantryRecipeCandidate] {
        lastRequestedPantryNames = pantryIngredientNames
        lastRequestedPreferences = preferences
        if let errorToThrow { throw errorToThrow }
        return candidates
    }

    // MARK: - Sample data

    static let sampleRecipes: [Recipe] = [
        Recipe(
            id: 1,
            title: "Lemon Garlic Roasted Salmon",
            imageURL: nil,
            readyInMinutes: 25,
            servings: 2,
            sourceURL: URL(string: "https://example.com/salmon"),
            sourceName: "Example Kitchen",
            summary: "A bright, weeknight-friendly salmon with lemon and garlic.",
            healthScore: 92,
            diets: ["pescetarian", "gluten free"],
            requiredIngredients: [
                RecipeIngredient(id: 15076, name: "salmon", requiredQuantity: 2, unit: .pieces),
                RecipeIngredient(id: 9150, name: "lemon", requiredQuantity: 1, unit: .pieces),
                RecipeIngredient(id: 11215, name: "garlic", requiredQuantity: 2, unit: .pieces),
            ],
            analyzedSteps: [
                RecipeInstructionStep(id: 1, stepText: "Heat the oven to 200C.", ingredientNames: []),
                RecipeInstructionStep(id: 2, stepText: "Roast the salmon with lemon and garlic for 12 minutes.", ingredientNames: ["salmon", "lemon", "garlic"]),
            ],
            containsAllergens: [.seafood]
        ),
        Recipe(
            id: 2,
            title: "Chickpea and Spinach Curry",
            imageURL: nil,
            readyInMinutes: 35,
            servings: 4,
            sourceURL: URL(string: "https://example.com/curry"),
            sourceName: "Example Kitchen",
            summary: "A cozy, protein-packed curry that comes together in one pot.",
            healthScore: 88,
            diets: ["vegan", "vegetarian", "dairy free"],
            requiredIngredients: [
                RecipeIngredient(id: 16057, name: "chickpeas", requiredQuantity: 400, unit: .grams),
                RecipeIngredient(id: 11457, name: "spinach", requiredQuantity: 200, unit: .grams),
                RecipeIngredient(id: 1022047, name: "curry powder", requiredQuantity: 1, unit: .tablespoons),
            ],
            analyzedSteps: [
                RecipeInstructionStep(id: 1, stepText: "Simmer chickpeas with curry powder.", ingredientNames: ["chickpeas", "curry powder"]),
                RecipeInstructionStep(id: 2, stepText: "Stir in the spinach until wilted.", ingredientNames: ["spinach"]),
            ],
            containsAllergens: []
        ),
        Recipe(
            id: 3,
            title: "Classic Margherita Pizza",
            imageURL: nil,
            readyInMinutes: 40,
            servings: 4,
            sourceURL: URL(string: "https://example.com/pizza"),
            sourceName: "Example Kitchen",
            summary: "Simple, fresh, and always a crowd-pleaser.",
            healthScore: 55,
            diets: ["vegetarian"],
            requiredIngredients: [
                RecipeIngredient(id: 20081, name: "flour", requiredQuantity: 500, unit: .grams),
                RecipeIngredient(id: 1026, name: "mozzarella", requiredQuantity: 200, unit: .grams),
                RecipeIngredient(id: 11529, name: "tomato", requiredQuantity: 3, unit: .pieces),
            ],
            analyzedSteps: [
                RecipeInstructionStep(id: 1, stepText: "Stretch the dough and top with tomato and mozzarella.", ingredientNames: ["flour", "tomato", "mozzarella"]),
            ],
            containsAllergens: [.dairy, .gluten, .wheat]
        ),
    ]

    /// Candidates as the recipe service would return them for a typical pantry.
    static let sampleCandidates: [PantryRecipeCandidate] = [
        PantryRecipeCandidate(
            recipe: sampleRecipes[1],
            usedIngredientNames: ["chickpeas", "spinach"],
            missedIngredients: [sampleRecipes[1].requiredIngredients[2]]
        ),
        PantryRecipeCandidate(
            recipe: sampleRecipes[2],
            usedIngredientNames: ["flour", "tomato"],
            missedIngredients: [sampleRecipes[2].requiredIngredients[1]]
        ),
        PantryRecipeCandidate(
            recipe: sampleRecipes[0],
            usedIngredientNames: ["lemon", "garlic"],
            missedIngredients: [sampleRecipes[0].requiredIngredients[0]]
        ),
    ]
}
