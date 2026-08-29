import Foundation

/// Persists `UserPreferences` to disk so dietary settings survive app relaunches.
protocol UserPreferencesStoring {
    func load() -> UserPreferences
    func save(_ preferences: UserPreferences)
}

final class UserPreferencesStore: UserPreferencesStoring {
    private let defaults: UserDefaults
    private let key = "com.lettucedecide.userPreferences"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> UserPreferences {
        guard
            let data = defaults.data(forKey: key),
            let decoded = try? JSONDecoder().decode(UserPreferences.self, from: data)
        else {
            return .default
        }
        return decoded
    }

    func save(_ preferences: UserPreferences) {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: key)
    }
}

/// In-memory store for previews and tests — never touches real UserDefaults.
final class InMemoryUserPreferencesStore: UserPreferencesStoring {
    private var stored: UserPreferences

    init(initial: UserPreferences = .default) {
        self.stored = initial
    }

    func load() -> UserPreferences { stored }
    func save(_ preferences: UserPreferences) { stored = preferences }
}
