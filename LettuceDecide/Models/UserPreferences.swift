import Foundation

/// The user's saved dietary settings, used to build recommendation requests.
struct UserPreferences: Codable, Equatable {
    var intolerances: Set<DietaryRestriction>
    var diet: DietPreference
    var maxReadyTimeMinutes: Int?
    var excludedIngredients: [String]

    static let `default` = UserPreferences(
        intolerances: [],
        diet: .none,
        maxReadyTimeMinutes: nil,
        excludedIngredients: []
    )
}
