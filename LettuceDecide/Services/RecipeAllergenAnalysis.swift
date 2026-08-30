import Foundation

/// Derives the allergens a recipe contains from its ingredient list, cross-checked against
/// Spoonacular's own "free from" flags.
///
/// This exists because the safety filter must not blindly trust Spoonacular's tags. It is
/// deliberately best-effort keyword matching: it errs towards *over*-reporting (a recipe
/// with "peanut butter" is flagged for dairy as well), because for an allergy filter a
/// false positive is a missed meal and a false negative is a hospital visit. When there are
/// no ingredient names to analyse it returns `nil`, which callers treat as unverified.
enum RecipeAllergenAnalysis {
    static func allergens(
        inIngredientNames names: [String],
        knownDairyFree: Bool = false,
        knownGlutenFree: Bool = false,
        vegan: Bool = false,
        vegetarian: Bool = false
    ) -> Set<DietaryRestriction>? {
        let cleaned = names
            .map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return nil }

        var found: Set<DietaryRestriction> = []
        for (restriction, keywords) in keywordsByRestriction {
            let hit = keywords.contains { keyword in
                cleaned.contains { $0.contains(keyword) }
            }
            if hit { found.insert(restriction) }
        }

        // Spoonacular's positive "free from" signals override keyword false positives.
        if knownDairyFree { found.remove(.dairy) }
        if knownGlutenFree { found.remove(.gluten); found.remove(.wheat) }
        if vegan { found.subtract([.dairy, .egg, .seafood, .shellfish]) }
        if vegetarian { found.subtract([.seafood, .shellfish]) }

        return found
    }

    private static let keywordsByRestriction: [DietaryRestriction: [String]] = [
        .dairy: ["milk", "cheese", "cream", "butter", "yogurt", "yoghurt", "ghee", "casein", "whey", "custard"],
        .egg: ["egg", "mayonnaise", "meringue"],
        .gluten: ["wheat", "flour", "barley", "rye", "malt", "bread", "pasta", "couscous", "semolina", "farro", "bulgur", "seitan"],
        .grain: ["rice", "oat", "corn", "quinoa", "wheat", "barley", "rye", "millet", "buckwheat", "sorghum"],
        .peanut: ["peanut", "groundnut"],
        .seafood: ["fish", "salmon", "tuna", "cod", "anchovy", "sardine", "tilapia", "haddock", "trout", "mackerel", "halibut"],
        .sesame: ["sesame", "tahini"],
        .shellfish: ["shrimp", "prawn", "crab", "lobster", "clam", "mussel", "oyster", "scallop", "squid", "calamari", "crawfish"],
        .soy: ["soy", "soya", "tofu", "edamame", "tempeh", "miso"],
        .sulfite: ["wine", "dried apricot", "raisin"],
        .treeNut: ["almond", "cashew", "walnut", "pecan", "pistachio", "hazelnut", "macadamia", "brazil nut", "pine nut", "praline"],
        .wheat: ["wheat", "flour", "bread", "pasta", "couscous", "semolina", "farro", "bulgur"],
    ]
}
