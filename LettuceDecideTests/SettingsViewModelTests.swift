import Foundation
import Testing
@testable import LettuceDecide

@MainActor
struct SettingsViewModelTests {
    @Test func toggleAddsAndRemovesRestrictions() {
        let viewModel = SettingsViewModel(store: InMemoryUserPreferencesStore())

        #expect(!viewModel.isSelected(.peanut))
        viewModel.toggle(.peanut)
        #expect(viewModel.isSelected(.peanut))
        viewModel.toggle(.peanut)
        #expect(!viewModel.isSelected(.peanut))
    }

    @Test func changesPersistThroughTheUseCase() {
        let store = InMemoryUserPreferencesStore()
        let viewModel = SettingsViewModel(store: store)

        viewModel.toggle(.dairy)
        viewModel.preferences.diet = .vegetarian

        #expect(store.load().intolerances.contains(.dairy))
        #expect(store.load().diet == .vegetarian)
    }

    @Test func loadsExistingPreferencesFromStore() {
        var prefs = UserPreferences.default
        prefs.intolerances = [.wheat]
        let store = InMemoryUserPreferencesStore(initial: prefs)

        let viewModel = SettingsViewModel(store: store)

        #expect(viewModel.isSelected(.wheat))
    }
}
