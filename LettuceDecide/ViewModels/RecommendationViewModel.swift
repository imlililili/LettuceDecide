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

    private let recommendMeals: RecommendMealsFromPantryUseCase

    init(recommendMeals: RecommendMealsFromPantryUseCase) {
        self.recommendMeals = recommendMeals
    }

    func decide() async {
        state = .loading
        do {
            let results = try await recommendMeals.execute()
            if let top = results.first {
                state = .loaded(top.recipe)
            } else {
                state = .failed(MealRecommendationError.noSafeRecipesAvailable.localizedDescription)
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
