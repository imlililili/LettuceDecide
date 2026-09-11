import Foundation

/// Something that can go wrong when generating a weekly meal plan.
enum WeeklyMealPlanError: LocalizedError {
    case noPantryIngredientsRecorded
    case incompleteWeek(daysProvided: Int)
    case recommendationServiceUnavailable(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .noPantryIngredientsRecorded:
            return "You haven't added anything to your pantry yet. Add a few ingredients so FridgeFit can plan your week."
        case .incompleteWeek(let daysProvided):
            return "Set how busy you'll be for all 7 days first (you've set \(daysProvided))."
        case .recommendationServiceUnavailable(let underlying):
            // "Check your connection" is only honest for a genuine connectivity failure. A bad
            // API key, a non-2xx response, or a response the app couldn't parse are different
            // problems with different fixes — collapsing them into one network-sounding
            // message wastes debugging time chasing the wrong cause (regression: a corrupted
            // API key surfaced as this exact message and looked like a network outage).
            guard let repositoryError = underlying as? RecipeRepositoryError else {
                return "Couldn't reach the recipe service. Check your connection and try again."
            }
            switch repositoryError {
            case .network:
                return "Couldn't reach the recipe service. Check your connection and try again."
            case .missingAPIKey, .invalidResponse, .requestFailed, .noResultsFound:
                return repositoryError.errorDescription
            }
        }
    }
}

/// Business operation: given a week of `ScheduleEntry`s, the current pantry, and the dietary
/// profile, produce a `WeeklyMealPlan`.
///
/// It makes **one** call to the recipe service for a candidate pool — the same
/// pantry-matched, allergen-filtered query the daily recommendations use — then hands the
/// pure assignment to `WeeklyPlanBuilder`. Nothing here touches the real pantry: the plan is
/// a preview.
struct GenerateWeeklyMealPlanUseCase {
    let recipeRepository: RecipeRepository
    let pantryStore: PantryStoring
    let preferencesStore: UserPreferencesStoring

    func execute(week entries: [ScheduleEntry], now: Date = Date()) async throws -> WeeklyMealPlan {
        let pantry = pantryStore.load()
        guard !pantry.isEmpty else {
            throw WeeklyMealPlanError.noPantryIngredientsRecorded
        }
        guard entries.count >= 7 else {
            throw WeeklyMealPlanError.incompleteWeek(daysProvided: entries.count)
        }

        let preferences = preferencesStore.load()

        let candidates: [PantryRecipeCandidate]
        do {
            candidates = try await recipeRepository.findRecipes(
                usingPantryNames: pantry.map(\.ingredientName),
                matching: preferences
            )
        } catch {
            throw WeeklyMealPlanError.recommendationServiceUnavailable(underlying: error)
        }

        // Safety (zero tolerance): re-check every candidate client-side, exactly as
        // RecommendMealsFromPantryUseCase does — the service's filter is a first pass only.
        let safe = candidates.filter { $0.recipe.isSafe(for: preferences.intolerances) }

        var plan = WeeklyPlanBuilder.build(
            candidates: safe,
            busyness: entries,
            startingFrom: pantry,
            now: now
        )
        plan.isFromCache = candidates.contains { $0.isFromCache }
        return plan
    }
}
