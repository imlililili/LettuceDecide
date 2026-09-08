import Foundation

/// Something that can go wrong when saving the cook's dietary settings.
enum UserPreferencesError: LocalizedError, Equatable {
    case invalidMaxReadyTime(minutes: Int)

    var errorDescription: String? {
        switch self {
        case .invalidMaxReadyTime(let minutes):
            return "A maximum cooking time of \(minutes) minutes doesn't make sense — pick a positive number of minutes, or leave it unset."
        }
    }
}

/// Business operation: persist a change to the cook's dietary settings — allergies and
/// intolerances, diet, excluded ingredients, maximum cooking time.
///
/// This is deliberately a use case and not a direct `store.save` from the view model.
/// Allergen data is safety-critical: it decides which recipes are filtered out, so every
/// write to it goes through the same layer as every other domain mutation. Today the only
/// rule is that a maximum cooking time, if set, must be positive; when more preference rules
/// arrive (e.g. reconciling conflicting entries) this is where they live.
struct UpdateUserPreferencesUseCase {
    let store: UserPreferencesStoring

    /// - Returns: the preferences as saved, so callers can keep their copy in sync.
    @discardableResult
    func execute(_ preferences: UserPreferences) throws -> UserPreferences {
        if let maxReadyTime = preferences.maxReadyTimeMinutes, maxReadyTime <= 0 {
            throw UserPreferencesError.invalidMaxReadyTime(minutes: maxReadyTime)
        }
        store.save(preferences)
        return preferences
    }
}
