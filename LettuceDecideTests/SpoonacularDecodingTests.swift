import Foundation
import Testing
@testable import LettuceDecide

private final class BundleToken {}

private func fixtureData(_ name: String) throws -> Data {
    let bundle = Bundle(for: BundleToken.self)
    let url = bundle.url(forResource: name, withExtension: "json")
        ?? bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
    return try Data(contentsOf: try #require(url, "missing fixture \(name).json"))
}

/// Locks the wire decoding against a real (sanitised) `complexSearch` response — the shape
/// hand-written JSON tends to miss: empty and non-metric units, ingredients Spoonacular
/// only half-populates, and the used/missing split.
struct SpoonacularRealResponseDecodingTests {
    private func candidates() throws -> [PantryRecipeCandidate] {
        try SpoonacularRecipeRepository.parseCandidates(from: fixtureData("spoonacular_complexSearch"))
    }

    @Test func decodesEveryResultWithoutFailing() throws {
        #expect(try candidates().count == 2)
    }

    @Test func mapsExtendedIngredientsToRecipeIngredientsWithQuantityAndUnit() throws {
        let hawaiian = try #require(try candidates().first { $0.recipe.title == "Instant Pot Hawaiian Chicken" })
        let byName = Dictionary(uniqueKeysWithValues: hawaiian.recipe.requiredIngredients.map { ($0.name, $0) })

        // Known metric-ish unit is kept.
        #expect(byName["barbecue sauce"]?.requiredQuantity == 16)
        // "oz" is not in IngredientUnit — it must fall back to .pieces, not fail the decode.
        #expect(byName["barbecue sauce"]?.unit == .pieces)
        // Empty unit string also falls back to .pieces.
        #expect(byName["chicken breasts"]?.unit == .pieces)
        #expect(byName["chicken breasts"]?.requiredQuantity == 3)
    }

    @Test func keepsRecognisedUnitsThatAreInTheSet() throws {
        let maki = try #require(try candidates().first { $0.recipe.title == "Kappa Maki" })
        let cups = maki.recipe.requiredIngredients.first { $0.unit == .cups }
        #expect(cups != nil, "expected the 'cups' ingredient to keep its unit")
    }

    @Test func analyzedStepsAreNonEmptyOrderedAndUntruncated() throws {
        let hawaiian = try #require(try candidates().first { $0.recipe.title == "Instant Pot Hawaiian Chicken" })
        let steps = hawaiian.recipe.analyzedSteps

        #expect(steps.count == 5)
        #expect(steps.map(\.id) == [1, 2, 3, 4, 5])
        // Full sentence, not clipped.
        #expect(steps.first?.stepText.hasSuffix(".") == true)
        #expect((steps.first?.stepText.count ?? 0) > 20)
    }

    @Test func carriesSourceAttribution() throws {
        for candidate in try candidates() {
            #expect(candidate.recipe.sourceName?.isEmpty == false)
            #expect(candidate.recipe.sourceURL != nil)
        }
    }

    @Test func splitsUsedAndMissedIngredients() throws {
        let hawaiian = try #require(try candidates().first { $0.recipe.title == "Instant Pot Hawaiian Chicken" })
        #expect(hawaiian.usedIngredientNames.contains { $0.contains("chicken") })
        #expect(hawaiian.missedIngredients.map(\.name).contains("barbecue sauce"))
    }
}

/// Targeted edge cases that a captured fixture happens not to contain.
struct SpoonacularDecodingEdgeCaseTests {
    @Test func stepsAreSortedByNumberEvenWhenTheApiReturnsThemOutOfOrder() throws {
        let json = """
        { "results": [ { "id": 1, "title": "T", "analyzedInstructions": [
            { "steps": [
                { "number": 3, "step": "Third." },
                { "number": 1, "step": "First." },
                { "number": 2, "step": "Second." }
            ] } ] } ] }
        """.data(using: .utf8)!

        let steps = try SpoonacularRecipeRepository.parseCandidates(from: json).first?.recipe.analyzedSteps
        #expect(steps?.map(\.id) == [1, 2, 3])
        #expect(steps?.map(\.stepText) == ["First.", "Second.", "Third."])
    }

    @Test func unknownUnitFallsBackToPiecesAndMissingAmountBecomesZero() throws {
        let json = """
        { "results": [ { "id": 1, "title": "T", "extendedIngredients": [
            { "id": 10, "name": "pork", "unit": "pound" },
            { "id": 11, "name": "salt", "amount": 2, "unit": "teaspoons" }
        ] } ] }
        """.data(using: .utf8)!

        let ingredients = try #require(
            try SpoonacularRecipeRepository.parseCandidates(from: json).first?.recipe.requiredIngredients
        )
        let pork = try #require(ingredients.first { $0.name == "pork" })
        #expect(pork.unit == .pieces)
        #expect(pork.requiredQuantity == 0)
        #expect(ingredients.first { $0.name == "salt" }?.unit == .teaspoons)
    }

    /// Regression for the diagnosed "onion 200 pcs" bug: Spoonacular sometimes puts
    /// "servings"/"serving" in an ingredient's unit field (e.g. "4 servings" of green onion
    /// on one recipe line) — not a real piece count. Confirmed live against the real API.
    /// The amount must be flagged uncertain, not silently trusted as `.pieces`.
    @Test func servingsUnitFlagsTheQuantityAsUncertain() throws {
        let json = """
        { "results": [ { "id": 1, "title": "T", "extendedIngredients": [
            { "id": 20, "name": "green onions", "amount": 4, "unit": "servings" },
            { "id": 21, "name": "onion", "amount": 12, "unit": "serving" },
            { "id": 22, "name": "flour", "amount": 200, "unit": "grams" }
        ] } ] }
        """.data(using: .utf8)!

        let ingredients = try #require(
            try SpoonacularRecipeRepository.parseCandidates(from: json).first?.recipe.requiredIngredients
        )

        let greenOnions = try #require(ingredients.first { $0.name == "green onions" })
        #expect(greenOnions.quantityIsUncertain)
        #expect(greenOnions.unit == .pieces) // still structurally .pieces, just flagged untrustworthy

        let onion = try #require(ingredients.first { $0.name == "onion" })
        #expect(onion.quantityIsUncertain) // singular "serving" too

        let flour = try #require(ingredients.first { $0.name == "flour" })
        #expect(!flour.quantityIsUncertain)
    }

    /// "c" is a common Spoonacular abbreviation for cups (confirmed live: 9 occurrences in a
    /// single 100-recipe sample) that wasn't in the recognised set — it fell back to
    /// `.pieces`, quietly miscategorising a volume amount as a piece count.
    @Test func cAbbreviationIsRecognisedAsCups() throws {
        let json = """
        { "results": [ { "id": 1, "title": "T", "extendedIngredients": [
            { "id": 30, "name": "caramelized onions", "amount": 0.667, "unit": "c" }
        ] } ] }
        """.data(using: .utf8)!

        let ingredient = try #require(
            try SpoonacularRecipeRepository.parseCandidates(from: json).first?.recipe.requiredIngredients.first
        )
        #expect(ingredient.unit == .cups)
        #expect(!ingredient.quantityIsUncertain)
    }

    @Test func emptyResultsListDecodesToNoCandidates() throws {
        let json = #"{ "results": [] }"#.data(using: .utf8)!
        #expect(try SpoonacularRecipeRepository.parseCandidates(from: json).isEmpty)
    }

    @Test func malformedJSONThrowsInvalidResponse() {
        let json = #"{ "results": "not an array" }"#.data(using: .utf8)!
        #expect(throws: RecipeRepositoryError.self) {
            _ = try SpoonacularRecipeRepository.parseCandidates(from: json)
        }
    }
}
