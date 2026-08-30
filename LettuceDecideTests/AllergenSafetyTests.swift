import Foundation
import Testing
@testable import LettuceDecide

private struct StubItem: AllergenDeclaring {
    let containsAllergens: Set<DietaryRestriction>?
}

struct AllergenDeclaringTests {
    @Test func noRestrictionsIsAlwaysSafeEvenWhenUnverified() {
        #expect(StubItem(containsAllergens: nil).isSafe(for: []))
        #expect(StubItem(containsAllergens: [.peanut]).isSafe(for: []))
    }

    @Test func unverifiedDataIsUnsafeWhenAnyRestrictionDeclared() {
        #expect(StubItem(containsAllergens: nil).isSafe(for: [.gluten]) == false)
    }

    @Test func knownSafeWhenAllergensDisjointFromRestrictions() {
        #expect(StubItem(containsAllergens: [.dairy]).isSafe(for: [.peanut, .shellfish]))
    }

    @Test func knownUnsafeWhenAllergensOverlapRestrictions() {
        #expect(StubItem(containsAllergens: [.dairy, .egg]).isSafe(for: [.egg]) == false)
    }

    @Test func recipeConformsAndFailsClosedOnMissingAllergenData() {
        let recipe = Recipe(id: 1, title: "Mystery Stew", containsAllergens: nil)
        #expect(recipe.isSafe(for: []) == true)
        #expect(recipe.isSafe(for: [.shellfish]) == false)
    }
}

struct RecipeAllergenAnalysisTests {
    @Test func returnsNilWhenNoIngredientNamesToAnalyse() {
        #expect(RecipeAllergenAnalysis.allergens(inIngredientNames: []) == nil)
    }

    @Test func detectsShellfishFromIngredientName() {
        let found = RecipeAllergenAnalysis.allergens(inIngredientNames: ["raw shrimp", "garlic", "olive oil"])
        #expect(found?.contains(.shellfish) == true)
    }

    @Test func detectsEggAndDairyFromIngredientNames() {
        let found = RecipeAllergenAnalysis.allergens(inIngredientNames: ["large eggs", "whole milk", "sugar"])
        #expect(found?.contains(.egg) == true)
        #expect(found?.contains(.dairy) == true)
    }

    @Test func spoonacularDairyFreeFlagOverridesButterKeyword() {
        let found = RecipeAllergenAnalysis.allergens(
            inIngredientNames: ["vegan butter", "flour"],
            knownDairyFree: true
        )
        #expect(found?.contains(.dairy) == false)
    }

    @Test func veganFlagClearsAnimalAllergens() {
        let found = RecipeAllergenAnalysis.allergens(
            inIngredientNames: ["egg replacer", "oat milk", "tofu"],
            vegan: true
        )
        #expect(found?.contains(.egg) == false)
        #expect(found?.contains(.dairy) == false)
        #expect(found?.contains(.soy) == true)
    }
}

struct RecipeInstructionStepTests {
    @Test func roundTripsThroughJSON() throws {
        let step = RecipeInstructionStep(id: 1, stepText: "Chop the onion.", ingredientNames: ["onion"])
        let data = try JSONEncoder().encode(step)
        #expect(try JSONDecoder().decode(RecipeInstructionStep.self, from: data) == step)
    }
}

struct RecipeCodableToleranceTests {
    @Test func decodesLegacyJSONWithoutNewFields() throws {
        let legacy = """
        { "id": 7, "title": "Old Recipe", "diets": ["vegan"] }
        """.data(using: .utf8)!
        let recipe = try JSONDecoder().decode(Recipe.self, from: legacy)
        #expect(recipe.id == 7)
        #expect(recipe.requiredIngredients.isEmpty)
        #expect(recipe.analyzedSteps.isEmpty)
        #expect(recipe.containsAllergens == nil)
    }
}
