//
//  LettuceDecideTests.swift
//  LettuceDecideTests
//
//  Created by Emily on 30/8/2026.
//

import Foundation
import Testing
@testable import LettuceDecide

struct UserPreferencesTests {
    @Test func defaultPreferencesHaveNoRestrictions() {
        let prefs = UserPreferences.default
        #expect(prefs.intolerances.isEmpty)
        #expect(prefs.diet == .none)
        #expect(prefs.maxReadyTimeMinutes == nil)
        #expect(prefs.excludedIngredients.isEmpty)
    }

    @Test func preferencesRoundTripThroughJSON() throws {
        var prefs = UserPreferences.default
        prefs.intolerances = [.dairy, .gluten]
        prefs.diet = .vegan
        prefs.maxReadyTimeMinutes = 30

        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(UserPreferences.self, from: data)

        #expect(decoded == prefs)
    }
}

struct DietaryRestrictionTests {
    @Test func apiValueMatchesSpoonacularIntoleranceNames() {
        #expect(DietaryRestriction.treeNut.apiValue == "Tree Nut")
        #expect(DietaryRestriction.dairy.apiValue == "dairy")
    }

    @Test func allCasesHaveUniqueRawValues() {
        let rawValues = DietaryRestriction.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }
}

struct RecipeTests {
    @Test func plainSummaryStripsHTMLTags() {
        let recipe = Recipe(id: 1, title: "Test", summary: "<b>Tasty</b> and <i>quick</i>.")
        #expect(recipe.plainSummary == "Tasty and quick.")
    }

    @Test func plainSummaryIsNilWhenSummaryIsNil() {
        let recipe = Recipe(id: 1, title: "Test")
        #expect(recipe.plainSummary == nil)
    }
}
