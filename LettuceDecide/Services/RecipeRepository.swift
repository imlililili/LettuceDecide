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

/// Finds recipes the cook can make from ingredients they already have.
protocol RecipeRepository {
    /// Recipes that use one or more of `pantryIngredientNames`, honouring `preferences`.
    ///
    /// The service decides which supplied ingredients each recipe uses and which further
    /// ingredients it needs — this app does not re-derive that ingredient match itself.
    func findRecipes(
        usingPantryNames pantryIngredientNames: [String],
        matching preferences: UserPreferences
    ) async throws -> [PantryRecipeCandidate]
}
