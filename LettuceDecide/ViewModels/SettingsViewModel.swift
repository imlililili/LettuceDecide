import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var preferences: UserPreferences {
        didSet { store.save(preferences) }
    }

    private let store: UserPreferencesStoring

    init(store: UserPreferencesStoring) {
        self.store = store
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
