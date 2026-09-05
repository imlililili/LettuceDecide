import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                Picker("Diet", selection: $viewModel.preferences.diet) {
                    ForEach(DietPreference.allCases) { diet in
                        Text(diet.displayName).tag(diet)
                    }
                }
            } header: {
                Text("Diet")
            }

            Section {
                ForEach(DietaryRestriction.allCases) { restriction in
                    Toggle(isOn: Binding(
                        get: { viewModel.isSelected(restriction) },
                        set: { viewModel.setRestriction(restriction, isOn: $0) }
                    )) {
                        Label(restriction.displayName, systemImage: restriction.symbolName)
                    }
                }
            } header: {
                Text("Allergies & Intolerances")
            } footer: {
                Text("Recipes containing these will be filtered out of your recommendations.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettingsView(viewModel: SettingsViewModel(store: InMemoryUserPreferencesStore()))
    }
}
