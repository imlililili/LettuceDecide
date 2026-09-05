import Foundation

/// Pure ranking logic — no network, no storage. Given recipe candidates from the recipe
/// service and the cook's actual pantry, it produces the ordered list the Recommendations
/// screen shows.
///
/// Ordering (business rule):
/// 1. recipes that use an expiring/expired pantry ingredient come before those that don't;
/// 2. within each group, higher pantry-match percentage comes first;
/// 3. recipe id as a final deterministic tie-break.
struct PantryMatcher {
    func match(
        candidates: [PantryRecipeCandidate],
        against pantry: [PantryIngredient],
        now: Date = Date()
    ) -> [PantryMatchResult] {
        candidates
            .map { candidate in makeResult(for: candidate, pantry: pantry, now: now) }
            .sorted(by: Self.ordering)
    }

    private func makeResult(
        for candidate: PantryRecipeCandidate,
        pantry: [PantryIngredient],
        now: Date
    ) -> PantryMatchResult {
        let usedKeys = Set(candidate.usedIngredientNames.map(\.normalizedIngredientName))
        let matched = pantry.filter { usedKeys.contains($0.ingredientName.normalizedIngredientName) }
        let usesExpiring = matched.contains { $0.expiryStatus(asOf: now).needsUsingUp }

        return PantryMatchResult(
            id: candidate.recipe.id,
            recipe: candidate.recipe,
            matchedIngredients: matched,
            missingIngredients: candidate.missedIngredients,
            usesExpiringIngredients: usesExpiring,
            isFromCache: candidate.isFromCache
        )
    }

    static func ordering(_ lhs: PantryMatchResult, _ rhs: PantryMatchResult) -> Bool {
        if lhs.usesExpiringIngredients != rhs.usesExpiringIngredients {
            return lhs.usesExpiringIngredients
        }
        if lhs.matchPercentage != rhs.matchPercentage {
            return lhs.matchPercentage > rhs.matchPercentage
        }
        return lhs.recipe.id < rhs.recipe.id
    }
}
