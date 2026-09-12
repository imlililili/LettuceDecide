import Foundation

/// Talks to the real Spoonacular API. See https://spoonacular.com/food-api/docs
final class SpoonacularRecipeRepository: RecipeRepository {
    private let baseURL = URL(string: "https://api.spoonacular.com/recipes")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func findRecipes(
        usingPantryNames pantryIngredientNames: [String],
        matching preferences: UserPreferences
    ) async throws -> [PantryRecipeCandidate] {
        let apiKey: String
        do {
            apiKey = try Config.requireAPIKey()
        } catch {
            throw RecipeRepositoryError.missingAPIKey
        }

        var components = URLComponents(
            url: baseURL.appendingPathComponent("complexSearch"),
            resolvingAgainstBaseURL: false
        )!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "apiKey", value: apiKey),
            // Spoonacular caps `number` at 100 for complexSearch, and we deliberately ask for
            // the max. A large share of its results carry no real prep-time data and get a
            // generic 45-minute placeholder for `readyInMinutes` — which fails both busyness
            // caps (.normal ≤40, .busy ≤20) — so genuinely fast-declared recipes are a thin
            // slice of any response (diagnosed live: ~12 non-placeholder results out of 100).
            // The weekly planner also needs enough distinct candidates to fill 7 days without
            // repeating a recipe. A small pool starves both; this one call is only made when
            // the cook explicitly asks for recommendations or a weekly plan, not on a timer.
            URLQueryItem(name: "number", value: "100"),
            URLQueryItem(name: "sort", value: "min-missing-ingredients"),
            URLQueryItem(name: "addRecipeInformation", value: "true"),
            // Without this, complexSearch omits analyzedInstructions/instructions
            // even with addRecipeInformation, and the detail screen has no method to show.
            URLQueryItem(name: "addRecipeInstructions", value: "true"),
            URLQueryItem(name: "fillIngredients", value: "true"),
        ]
        if !pantryIngredientNames.isEmpty {
            items.append(URLQueryItem(
                name: "includeIngredients",
                value: pantryIngredientNames.joined(separator: ",")
            ))
        }
        if !preferences.intolerances.isEmpty {
            items.append(URLQueryItem(
                name: "intolerances",
                value: preferences.intolerances.map(\.apiValue).joined(separator: ",")
            ))
        }
        if let diet = preferences.diet.apiValue {
            items.append(URLQueryItem(name: "diet", value: diet))
        }
        if let maxTime = preferences.maxReadyTimeMinutes {
            items.append(URLQueryItem(name: "maxReadyTime", value: String(maxTime)))
        }
        components.queryItems = items

        guard let url = components.url else { throw RecipeRepositoryError.invalidResponse }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw RecipeRepositoryError.network(error)
        }

        guard let http = response as? HTTPURLResponse else { throw RecipeRepositoryError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw RecipeRepositoryError.requestFailed(statusCode: http.statusCode)
        }

        return try Self.parseCandidates(from: data)
    }

    /// The wire-decoding step, split out so it can be exercised against real API fixtures
    /// without going through the network.
    static func parseCandidates(from data: Data) throws -> [PantryRecipeCandidate] {
        let decoded: SpoonacularSearchResponse
        do {
            decoded = try JSONDecoder().decode(SpoonacularSearchResponse.self, from: data)
        } catch {
            throw RecipeRepositoryError.invalidResponse
        }
        return decoded.results.map(\.asPantryCandidate)
    }
}

// MARK: - Wire types

private struct SpoonacularSearchResponse: Decodable {
    let results: [SpoonacularRecipe]
}

private struct SpoonacularIngredient: Decodable {
    let id: Int?
    let name: String?
    let nameClean: String?
    let amount: Double?
    let unit: String?

    var asRecipeIngredient: RecipeIngredient {
        // Diagnosed live: Spoonacular sometimes puts "servings" (or "serving") in the unit
        // field of a single ingredient line — e.g. "4 servings" of green onion on one recipe.
        // That's not a piece count; `amount` there means something else entirely (often a
        // per-serving ratio), and treating it as "4 pieces" produces a wildly inflated,
        // confident-looking wrong number once several recipes' worth get summed on a
        // shopping list. `IngredientUnit(spoonacularUnit:)` still maps it to `.pieces` for
        // structural reasons (every RecipeIngredient needs a concrete unit), but this flag is
        // what stops that number from being trusted downstream.
        let rawUnit = (unit ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return RecipeIngredient(
            id: id ?? abs((nameClean ?? name ?? "").hashValue),
            name: nameClean ?? name ?? "ingredient",
            requiredQuantity: amount ?? 0,
            unit: IngredientUnit(spoonacularUnit: unit ?? "") ?? .pieces,
            quantityIsUncertain: rawUnit == "serving" || rawUnit == "servings"
        )
    }
}

private struct SpoonacularRecipe: Decodable {
    let id: Int
    let title: String
    let image: String?
    let readyInMinutes: Int?
    let servings: Int?
    let sourceUrl: String?
    let sourceName: String?
    let summary: String?
    let healthScore: Double?
    let diets: [String]?
    let glutenFree: Bool?
    let dairyFree: Bool?
    let vegan: Bool?
    let vegetarian: Bool?
    let instructions: String?
    let extendedIngredients: [SpoonacularIngredient]?
    let analyzedInstructions: [AnalyzedInstruction]?
    let usedIngredients: [SpoonacularIngredient]?
    let missedIngredients: [SpoonacularIngredient]?

    struct AnalyzedInstruction: Decodable {
        let steps: [Step]

        struct Step: Decodable {
            let number: Int
            let step: String
            let ingredients: [NamedItem]?

            struct NamedItem: Decodable {
                let name: String?
            }
        }
    }

    var asRecipe: Recipe {
        let ingredients = (extendedIngredients ?? []).map(\.asRecipeIngredient)

        let steps: [RecipeInstructionStep] = (analyzedInstructions?.first?.steps ?? [])
            .sorted { $0.number < $1.number }
            .map { step in
                RecipeInstructionStep(
                    id: step.number,
                    stepText: step.step,
                    ingredientNames: (step.ingredients ?? []).compactMap(\.name)
                )
            }

        let ingredientNames = (extendedIngredients ?? []).compactMap { $0.nameClean ?? $0.name }
        let allergens = RecipeAllergenAnalysis.allergens(
            inIngredientNames: ingredientNames,
            knownDairyFree: dairyFree ?? false,
            knownGlutenFree: glutenFree ?? false,
            vegan: vegan ?? false,
            vegetarian: vegetarian ?? false
        )

        return Recipe(
            id: id,
            title: title,
            imageURL: image.flatMap(URL.init(string:)),
            readyInMinutes: readyInMinutes,
            servings: servings,
            sourceURL: sourceUrl.flatMap(URL.init(string:)),
            sourceName: sourceName,
            summary: summary,
            healthScore: healthScore,
            diets: diets ?? [],
            requiredIngredients: ingredients,
            analyzedSteps: steps,
            instructions: instructions,
            containsAllergens: allergens
        )
    }

    var asPantryCandidate: PantryRecipeCandidate {
        PantryRecipeCandidate(
            recipe: asRecipe,
            usedIngredientNames: (usedIngredients ?? []).compactMap { $0.nameClean ?? $0.name },
            missedIngredients: (missedIngredients ?? []).map(\.asRecipeIngredient)
        )
    }
}
