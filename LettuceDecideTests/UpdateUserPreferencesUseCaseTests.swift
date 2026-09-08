import Foundation
import Testing
@testable import LettuceDecide

struct UpdateUserPreferencesUseCaseTests {
    @Test func savesValidPreferencesThroughTheStore() throws {
        let store = InMemoryUserPreferencesStore()
        let useCase = UpdateUserPreferencesUseCase(store: store)

        var prefs = UserPreferences.default
        prefs.intolerances = [.dairy, .peanut]
        prefs.diet = .vegan
        prefs.maxReadyTimeMinutes = 30

        try useCase.execute(prefs)

        #expect(store.load() == prefs)
    }

    @Test func rejectsANonPositiveMaxCookingTimeAndDoesNotSave() {
        let store = InMemoryUserPreferencesStore(initial: .default)
        let useCase = UpdateUserPreferencesUseCase(store: store)

        var prefs = UserPreferences.default
        prefs.maxReadyTimeMinutes = 0

        #expect(throws: UserPreferencesError.invalidMaxReadyTime(minutes: 0)) {
            try useCase.execute(prefs)
        }
        #expect(store.load() == .default)
    }

    @Test func anUnsetMaxCookingTimeIsFine() throws {
        let store = InMemoryUserPreferencesStore()
        let useCase = UpdateUserPreferencesUseCase(store: store)

        var prefs = UserPreferences.default
        prefs.maxReadyTimeMinutes = nil

        try useCase.execute(prefs)

        #expect(store.load().maxReadyTimeMinutes == nil)
    }
}
