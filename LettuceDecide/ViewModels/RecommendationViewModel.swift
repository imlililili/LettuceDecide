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
        case loaded([PantryMatchResult])
        case failed(Failure)
    }

    @Published private(set) var state: State = .idle

    private let recommendMeals: RecommendMealsFromPantryUseCase
    private var pantryChangeCancellable: AnyCancellable?

    /// The candidate pool from the last successful fetch, kept so a pantry edit re-ranks it
    /// locally instead of triggering another network request.
    private var candidatePool: [PantryRecipeCandidate] = []

    init(recommendMeals: RecommendMealsFromPantryUseCase) {
        self.recommendMeals = recommendMeals
        pantryChangeCancellable = recommendMeals.pantryStore.changes
            .sink { [weak self] in
                MainActor.assumeIsolated { self?.recomputeFromCurrentPantry() }
            }
    }

    func decide() async {
        state = .loading
        do {
            let pool = try await recommendMeals.fetchSafeCandidates()
            candidatePool = pool
            let results = recommendMeals.rank(pool)
            if results.isEmpty {
                state = .failed(Failure(
                    message: MealRecommendationError.noSafeRecipesAvailable.localizedDescription,
                    recovery: .retry
                ))
            } else {
                state = .loaded(results)
            }
        } catch let error as MealRecommendationError {
            candidatePool = []
            state = .failed(Failure(message: error.localizedDescription, recovery: error.recovery))
        } catch {
            candidatePool = []
            state = .failed(Failure(message: error.localizedDescription, recovery: .retry))
        }
    }

    /// Re-ranks the retained candidate pool against the pantry as it stands now. Purely
    /// local — never calls the repository. A no-op unless there are loaded results to
    /// update (a failed or idle screen has no pool to re-rank).
    func recomputeFromCurrentPantry() {
        guard case .loaded = state, !candidatePool.isEmpty else { return }
        state = .loaded(recommendMeals.rank(candidatePool))
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
