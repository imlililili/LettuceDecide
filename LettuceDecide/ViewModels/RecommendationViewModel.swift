import Foundation
import Combine

@MainActor
final class RecommendationViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case loaded(Recipe)
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    private let engine: RecommendationEngine
    private let preferencesStore: UserPreferencesStoring

    init(engine: RecommendationEngine, preferencesStore: UserPreferencesStoring) {
        self.engine = engine
        self.preferencesStore = preferencesStore
    }

    func decide() async {
        state = .loading
        let preferences = preferencesStore.load()
        do {
            let recipe = try await engine.recommend(matching: preferences)
            state = .loaded(recipe)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
