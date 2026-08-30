import Foundation
import Combine

@MainActor
final class RecommendationViewModel: ObservableObject {
    /// How the user can recover from a failed recommendation.
    enum Recovery: Equatable {
        /// Re-running the request could succeed (network blip, changed settings).
        case retry
        /// The pantry is empty — retrying is pointless; send the user to add ingredients.
        case addIngredients
    }

    struct Failure: Equatable {
        let message: String
        let recovery: Recovery
    }

    enum State: Equatable {
        case idle
        case loading
        case loaded(Recipe)
        case failed(Failure)
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
                state = .failed(Failure(
                    message: MealRecommendationError.noSafeRecipesAvailable.localizedDescription,
                    recovery: .retry
                ))
            }
        } catch let error as MealRecommendationError {
            state = .failed(Failure(message: error.localizedDescription, recovery: error.recovery))
        } catch {
            state = .failed(Failure(message: error.localizedDescription, recovery: .retry))
        }
    }
}

private extension MealRecommendationError {
    var recovery: RecommendationViewModel.Recovery {
        switch self {
        case .noPantryIngredientsRecorded: return .addIngredients
        case .noSafeRecipesAvailable, .recommendationServiceUnavailable: return .retry
        }
    }
}
