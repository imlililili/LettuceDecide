import Foundation

/// A single recipe recommendation shown to the user.
struct Recipe: Identifiable, Codable, Equatable, Hashable {
    let id: Int
    let title: String
    let imageURL: URL?
    let readyInMinutes: Int?
    let servings: Int?
    let sourceURL: URL?
    /// Name of the site the recipe was published on (e.g. "AllRecipes"). Shown in the
    /// attribution line required by Spoonacular's terms whenever recipe content is displayed.
    let sourceName: String?
    /// HTML summary as returned by Spoonacular; render with an HTML-stripping helper before display.
    let summary: String?
    let healthScore: Double?
    let diets: [String]
    /// The ingredients this recipe calls for, with the amounts it needs.
    let requiredIngredients: [RecipeIngredient]
    /// Structured, numbered method steps. Preferred over `instructions` for display.
    let analyzedSteps: [RecipeInstructionStep]
    /// Plain/HTML instructions blob — fallback used only when `analyzedSteps` is empty.
    let instructions: String?
    /// Allergens this recipe is known to contain.
    ///
    /// Business rule: `nil` means the allergen data has **not** been verified — it is not a
    /// claim that the recipe is allergen-free. `AllergenDeclaring.isSafe(for:)` treats `nil`
    /// as unsafe whenever the cook has declared any restriction (fail closed).
    let containsAllergens: Set<DietaryRestriction>?

    init(
        id: Int,
        title: String,
        imageURL: URL? = nil,
        readyInMinutes: Int? = nil,
        servings: Int? = nil,
        sourceURL: URL? = nil,
        sourceName: String? = nil,
        summary: String? = nil,
        healthScore: Double? = nil,
        diets: [String] = [],
        requiredIngredients: [RecipeIngredient] = [],
        analyzedSteps: [RecipeInstructionStep] = [],
        instructions: String? = nil,
        containsAllergens: Set<DietaryRestriction>? = nil
    ) {
        self.id = id
        self.title = title
        self.imageURL = imageURL
        self.readyInMinutes = readyInMinutes
        self.servings = servings
        self.sourceURL = sourceURL
        self.sourceName = sourceName
        self.summary = summary
        self.healthScore = healthScore
        self.diets = diets
        self.requiredIngredients = requiredIngredients
        self.analyzedSteps = analyzedSteps
        self.instructions = instructions
        self.containsAllergens = containsAllergens
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        imageURL = try c.decodeIfPresent(URL.self, forKey: .imageURL)
        readyInMinutes = try c.decodeIfPresent(Int.self, forKey: .readyInMinutes)
        servings = try c.decodeIfPresent(Int.self, forKey: .servings)
        sourceURL = try c.decodeIfPresent(URL.self, forKey: .sourceURL)
        sourceName = try c.decodeIfPresent(String.self, forKey: .sourceName)
        summary = try c.decodeIfPresent(String.self, forKey: .summary)
        healthScore = try c.decodeIfPresent(Double.self, forKey: .healthScore)
        diets = try c.decodeIfPresent([String].self, forKey: .diets) ?? []
        requiredIngredients = try c.decodeIfPresent([RecipeIngredient].self, forKey: .requiredIngredients) ?? []
        analyzedSteps = try c.decodeIfPresent([RecipeInstructionStep].self, forKey: .analyzedSteps) ?? []
        instructions = try c.decodeIfPresent(String.self, forKey: .instructions)
        containsAllergens = try c.decodeIfPresent(Set<DietaryRestriction>.self, forKey: .containsAllergens)
    }
}

extension Recipe {
    /// A plain-text rendering of `summary` with HTML tags removed, for simple label display.
    var plainSummary: String? {
        summary?.htmlTagsStripped
    }

    /// Plain-text fallback instructions (used only when `analyzedSteps` is empty).
    var plainInstructions: String? {
        guard let instructions, !instructions.isEmpty else { return nil }
        let stripped = instructions.htmlTagsStripped.trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped.isEmpty ? nil : stripped
    }
}

extension String {
    var htmlTagsStripped: String {
        replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
}

// MARK: - AllergenDeclaring

extension Recipe: AllergenDeclaring {}
