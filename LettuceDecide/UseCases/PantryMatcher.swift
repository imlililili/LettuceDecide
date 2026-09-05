import Foundation

/// Pure ranking logic — no network, no storage. Given recipe candidates from the recipe
/// service and the cook's actual pantry, it produces the ordered list the Recommendations
/// screen shows.
///
/// Because it is pure, the same candidate pool can be re-ranked against a fresh pantry every
/// time the inventory changes, without going back to the service.
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
        let pantryKeys = Set(pantry.map { $0.ingredientName.normalizedIngredientName })
        let usedKeys = Set(candidate.usedIngredientNames.map(\.normalizedIngredientName))

        // Start from the service's used/missing split (it does the fuzzy name matching this
        // app deliberately doesn't), then reconcile against the current pantry: anything the
        // service called "missing" that the cook has since bought counts as matched now.
        // This is what lets a pantry edit move a recipe up the list — and fill in its
        // checklist — with no refetch.
        let nowStockedMissedKeys = Set(
            candidate.missedIngredients
                .map { $0.name.normalizedIngredientName }
                .filter(pantryKeys.contains)
        )
        let matchedKeys = usedKeys.union(nowStockedMissedKeys)

        let matched = pantry.filter { matchedKeys.contains($0.ingredientName.normalizedIngredientName) }
        let stillMissing = candidate.missedIngredients.filter {
            !nowStockedMissedKeys.contains($0.name.normalizedIngredientName)
        }
        let usesExpiring = matched.contains { $0.expiryStatus(asOf: now).needsUsingUp }

        return PantryMatchResult(
            id: candidate.recipe.id,
            recipe: candidate.recipe,
            matchedIngredients: matched,
            missingIngredients: stillMissing,
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
