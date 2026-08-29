import Foundation
import Testing
@testable import LettuceDecide

struct UserPreferencesStoreTests {
    @Test func inMemoryStoreReturnsDefaultWhenNothingSaved() {
        let store = InMemoryUserPreferencesStore()
        #expect(store.load() == .default)
    }

    @Test func inMemoryStoreRoundTripsSavedPreferences() {
        let store = InMemoryUserPreferencesStore()
        var prefs = UserPreferences.default
        prefs.intolerances = [.shellfish, .soy]
        prefs.diet = .paleo

        store.save(prefs)

        #expect(store.load() == prefs)
    }

    @Test func userDefaultsStoreRoundTripsSavedPreferences() {
        let suiteName = "com.lettucedecide.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserPreferencesStore(defaults: defaults)

        var prefs = UserPreferences.default
        prefs.intolerances = [.egg]
        prefs.maxReadyTimeMinutes = 20

        store.save(prefs)

        #expect(store.load() == prefs)
    }

    @Test func userDefaultsStoreReturnsDefaultWhenNothingSaved() {
        let suiteName = "com.lettucedecide.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserPreferencesStore(defaults: defaults)

        #expect(store.load() == .default)
    }
}
