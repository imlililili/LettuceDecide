import Foundation

/// Something that can go wrong when asking for meal recommendations.
enum MealRecommendationError: LocalizedError {
    case noPantryIngredientsRecorded
    case noSafeRecipesAvailable
    case recommendationServiceUnavailable(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .noPantryIngredientsRecorded:
            return "You haven't added anything to your pantry yet. Add a few ingredients so FridgeFit can suggest what to cook."
        case .noSafeRecipesAvailable:
            return "Nothing available right now fits your dietary settings. Try loosening a restriction in Settings, or add more ingredients."
        case .recommendationServiceUnavailable:
            return "Couldn't reach the recipe service. Check your connection and try again."
        }
    }
}

/// Business operation: given the cook's current pantry and dietary profile, return a ranked
/// list of recipes they can realistically make, steering them towards ingredients that are
/// about to expire.
///
/// Deliberately two steps. Fetching the candidate pool is the only part that does I/O and
/// must not be repeated just because the pantry changed; ranking that pool against the
/// pantry is pure and local, so it can re-run every time the inventory moves.
///
/// Protects two rules:
/// - **Safety (zero tolerance):** every candidate is re-checked client-side against the
///   cook's declared restrictions before it is shown. The recipe service's own filtering is
///   a first pass, not the last word — a recipe with unverified allergen data is dropped
///   whenever the cook has any restriction (see `AllergenDeclaring.isSafe(for:)`).
/// - **Transparency:** results come back as `PantryMatchResult`s, each carrying its
///   pantry-match percentage and the ingredients it is missing.
struct RecommendMealsFromPantryUseCase {
    let recipeRepository: RecipeRepository
    let pantryStore: PantryStoring
    let preferencesStore: UserPreferencesStoring
    var matcher = PantryMatcher()

    /// The I/O step: fetch the candidate pool and drop anything unsafe for the cook's
    /// declared restrictions. The result is **not** yet ranked against the pantry.
    func fetchSafeCandidates() async throws -> [PantryRecipeCandidate] {
        let pantry = pantryStore.load()
        guard !pantry.isEmpty else {
            throw MealRecommendationError.noPantryIngredientsRecorded
        }

        let preferences = preferencesStore.load()

        let candidates: [PantryRecipeCandidate]
        do {
            candidates = try await recipeRepository.findRecipes(
                usingPantryNames: pantry.map(\.ingredientName),
                matching: preferences
            )
        } catch {
            throw MealRecommendationError.recommendationServiceUnavailable(underlying: error)
        }

        let safe = candidates.filter { $0.recipe.isSafe(for: preferences.intolerances) }
        guard !safe.isEmpty else {
            throw MealRecommendationError.noSafeRecipesAvailable
        }
        return safe
    }

    /// The pure step: rank an already-fetched pool against the **current** pantry. No
    /// network, no dependency on when the pool was fetched — safe to call on every pantry
    /// change.
    func rank(_ candidates: [PantryRecipeCandidate], now: Date = Date()) -> [PantryMatchResult] {
        matcher.match(candidates: candidates, against: pantryStore.load(), now: now)
    }

    /// Fetch then rank — the original one-shot operation.
    func execute(now: Date = Date()) async throws -> [PantryMatchResult] {
        rank(try await fetchSafeCandidates(), now: now)
    }
}
