import SwiftUI

struct RecommendationView: View {
    @StateObject private var viewModel: RecommendationViewModel
    @StateObject private var settingsViewModel: SettingsViewModel
    @State private var showingSettings = false

    init(
        viewModel: @autoclosure @escaping () -> RecommendationViewModel,
        settingsViewModel: @autoclosure @escaping () -> SettingsViewModel
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        _settingsViewModel = StateObject(wrappedValue: settingsViewModel())
    }

    var body: some View {
        NavigationStack {
            VStack {
                Spacer(minLength: 0)
                content
                Spacer(minLength: 0)
                decideButton
            }
            .padding()
            .navigationTitle("Lettuce Decide")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(viewModel: settingsViewModel)
            }
            .task {
                if viewModel.state == .idle {
                    await viewModel.decide()
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            EmptyView()
        case .loading:
            LoadingView()
        case .loaded(let recipe):
            ScrollView {
                RecipeCardView(recipe: recipe)
            }
        case .failed(let message):
            ErrorStateView(message: message) {
                Task { await viewModel.decide() }
            }
        }
    }

    private var decideButton: some View {
        Button {
            Task { await viewModel.decide() }
        } label: {
            Label("Decide For Me", systemImage: "shuffle")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.state == .loading)
        .padding(.top)
    }
}

#Preview {
    RecommendationView(
        viewModel: RecommendationViewModel(
            engine: RecommendationEngine(repository: MockRecipeRepository()),
            preferencesStore: InMemoryUserPreferencesStore()
        ),
        settingsViewModel: SettingsViewModel(store: InMemoryUserPreferencesStore())
    )
}
