import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var preferences: UserPreferences {
        didSet {
            // Only the diet picker and the allergen toggles can reach here, and neither can
            // produce an invalid value — but the write still goes through the use case so
            // allergen data follows the same path as every other domain mutation.
            _ = try? updatePreferences.execute(preferences)
        }
    }

    private let updatePreferences: UpdateUserPreferencesUseCase

    init(store: UserPreferencesStoring) {
        self.updatePreferences = UpdateUserPreferencesUseCase(store: store)
        self.preferences = store.load()
    }

    func toggle(_ restriction: DietaryRestriction) {
        setRestriction(restriction, isOn: !preferences.intolerances.contains(restriction))
    }

    func setRestriction(_ restriction: DietaryRestriction, isOn: Bool) {
        if isOn {
            preferences.intolerances.insert(restriction)
        } else {
            preferences.intolerances.remove(restriction)
        }
    }

    func isSelected(_ restriction: DietaryRestriction) -> Bool {
        preferences.intolerances.contains(restriction)
    }
}
