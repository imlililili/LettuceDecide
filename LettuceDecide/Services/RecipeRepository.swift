import Foundation

enum RecipeRepositoryError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case requestFailed(statusCode: Int)
    case noResultsFound
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return Config.ConfigError.missingAPIKey.errorDescription
        case .invalidResponse:
            return "The server returned an unexpected response."
        case .requestFailed(let statusCode):
            return "The request failed (status \(statusCode))."
        case .noResultsFound:
            return "No recipes matched those settings. Try loosening a restriction."
        case .network(let error):
            return error.localizedDescription
        }
    }
}

/// Fetches recipe recommendations honoring a set of dietary preferences.
protocol RecipeRepository {
    func fetchRandomRecipe(matching preferences: UserPreferences, excluding excludedIDs: Set<Int>) async throws -> Recipe
}
