import Foundation

/// Talks to the real Spoonacular API. See https://spoonacular.com/food-api/docs
final class SpoonacularRecipeRepository: RecipeRepository {
    private let baseURL = URL(string: "https://api.spoonacular.com/recipes")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchRandomRecipe(matching preferences: UserPreferences, excluding excludedIDs: Set<Int>) async throws -> Recipe {
        let apiKey: String
        do {
            apiKey = try Config.requireAPIKey()
        } catch {
            throw RecipeRepositoryError.missingAPIKey
        }

        var components = URLComponents(url: baseURL.appendingPathComponent("complexSearch"), resolvingAgainstBaseURL: false)!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "sort", value: "random"),
            URLQueryItem(name: "number", value: "5"),
            URLQueryItem(name: "addRecipeInformation", value: "true"),
        ]
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
        if !preferences.excludedIngredients.isEmpty {
            items.append(URLQueryItem(
                name: "excludeIngredients",
                value: preferences.excludedIngredients.joined(separator: ",")
            ))
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

        let decoded: SpoonacularSearchResponse
        do {
            decoded = try JSONDecoder().decode(SpoonacularSearchResponse.self, from: data)
        } catch {
            throw RecipeRepositoryError.invalidResponse
        }

        let candidates = decoded.results.map(\.asRecipe).filter { !excludedIDs.contains($0.id) }
        guard let pick = candidates.randomElement() ?? decoded.results.first?.asRecipe else {
            throw RecipeRepositoryError.noResultsFound
        }
        return pick
    }
}

// MARK: - Wire types

private struct SpoonacularSearchResponse: Decodable {
    let results: [SpoonacularRecipe]
}

private struct SpoonacularRecipe: Decodable {
    let id: Int
    let title: String
    let image: String?
    let readyInMinutes: Int?
    let servings: Int?
    let sourceUrl: String?
    let summary: String?
    let healthScore: Double?
    let diets: [String]?

    var asRecipe: Recipe {
        Recipe(
            id: id,
            title: title,
            imageURL: image.flatMap(URL.init(string:)),
            readyInMinutes: readyInMinutes,
            servings: servings,
            sourceURL: sourceUrl.flatMap(URL.init(string:)),
            summary: summary,
            healthScore: healthScore,
            diets: diets ?? []
        )
    }
}
