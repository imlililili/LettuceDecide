import Foundation
import Testing
@testable import LettuceDecide

struct RecommendMealsFromPantryUseCaseTests {
    private let today = Date(timeIntervalSince1970: 1_700_000_000)
    private var inTwoDays: Date { Calendar.current.date(byAdding: .day, value: 2, to: today)! }

    private func makeUseCase(
        pantry: [PantryIngredient],
        candidates: [PantryRecipeCandidate] = MockRecipeRepository.sampleCandidates,
        preferences: UserPreferences = .default,
        repositoryError: Error? = nil
    ) -> RecommendMealsFromPantryUseCase {
        RecommendMealsFromPantryUseCase(
            recipeRepository: MockRecipeRepository(candidates: candidates, errorToThrow: repositoryError),
            pantryStore: InMemoryPantryStore(initial: pantry),
            preferencesStore: InMemoryUserPreferencesStore(initial: preferences)
        )
    }

    private func candidate(_ id: Int, allergens: Set<DietaryRestriction>?, used: [String] = ["onion"]) -> PantryRecipeCandidate {
        PantryRecipeCandidate(
            recipe: Recipe(id: id, title: "Recipe \(id)", containsAllergens: allergens),
            usedIngredientNames: used,
            missedIngredients: []
        )
    }

    @Test func recommendMeals_fails_whenPantryIsEmpty() async {
        let useCase = makeUseCase(pantry: [])

        await #expect(throws: MealRecommendationError.self) {
            _ = try await useCase.execute(now: today)
        }
    }

    @Test func recommendMeals_excludesRecipes_containingDeclaredAllergen() async throws {
        var prefs = UserPreferences.default
        prefs.intolerances = [.dairy]
        let useCase = makeUseCase(
            pantry: [PantryIngredient(ingredientName: "onion", quantity: 2, unit: .pieces, storageLocation: .pantry)],
            candidates: [
                candidate(1, allergens: [.dairy]),
                candidate(2, allergens: []),
            ],
            preferences: prefs
        )

        let results = try await useCase.execute(now: today)

        #expect(results.map(\.recipe.id) == [2])
    }

    @Test func recommendMeals_fails_whenEveryCandidateHasUnverifiedAllergenDataAndARestrictionIsSet() async {
        var prefs = UserPreferences.default
        prefs.intolerances = [.peanut]
        let useCase = makeUseCase(
            pantry: [PantryIngredient(ingredientName: "onion", quantity: 2, unit: .pieces, storageLocation: .pantry)],
            candidates: [candidate(1, allergens: nil), candidate(2, allergens: nil)],
            preferences: prefs
        )

        await #expect(throws: MealRecommendationError.self) {
            _ = try await useCase.execute(now: today)
        }
    }

    @Test func recommendMeals_prioritisesRecipes_usingExpiringIngredients() async throws {
        let pantry = [
            PantryIngredient(ingredientName: "tomato", quantity: 3, unit: .pieces, storageLocation: .fridge, expiryDate: inTwoDays),
            PantryIngredient(ingredientName: "rice", quantity: 500, unit: .grams, storageLocation: .pantry),
            PantryIngredient(ingredientName: "beans", quantity: 400, unit: .grams, storageLocation: .pantry),
        ]
        let useCase = makeUseCase(
            pantry: pantry,
            candidates: [
                PantryRecipeCandidate(
                    recipe: Recipe(id: 1, title: "Rice and Beans", containsAllergens: []),
                    usedIngredientNames: ["rice", "beans"],
                    missedIngredients: []
                ),
                PantryRecipeCandidate(
                    recipe: Recipe(id: 2, title: "Tomato Salad", containsAllergens: []),
                    usedIngredientNames: ["tomato"],
                    missedIngredients: [RecipeIngredient(id: 9, name: "feta", requiredQuantity: 100, unit: .grams)]
                ),
            ]
        )

        let results = try await useCase.execute(now: today)

        #expect(results.first?.recipe.id == 2)
        #expect(results.first?.usesExpiringIngredients == true)
    }

    @Test func recommendMeals_flagsResults_whenCandidatesCameFromTheCache() async throws {
        var cached = candidate(1, allergens: [])
        cached.isFromCache = true
        let useCase = makeUseCase(
            pantry: [PantryIngredient(ingredientName: "onion", quantity: 2, unit: .pieces, storageLocation: .pantry)],
            candidates: [cached, candidate(2, allergens: [])]
        )

        let results = try await useCase.execute(now: today)

        let anyFromCache = results.contains { $0.isFromCache }
        let recipeTwo = results.first { $0.recipe.id == 2 }
        #expect(anyFromCache)
        #expect(recipeTwo?.isFromCache == false)
    }

    @Test func recommendMeals_wrapsServiceErrors() async {
        let useCase = makeUseCase(
            pantry: [PantryIngredient(ingredientName: "onion", quantity: 2, unit: .pieces, storageLocation: .pantry)],
            repositoryError: RecipeRepositoryError.requestFailed(statusCode: 500)
        )

        await #expect(throws: MealRecommendationError.self) {
            _ = try await useCase.execute(now: today)
        }
    }
}
