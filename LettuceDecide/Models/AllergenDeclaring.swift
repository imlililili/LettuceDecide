import Foundation

/// A thing that can state which allergens it contains and answer whether it is safe for a
/// given set of dietary restrictions.
///
/// This is a domain behaviour, not just a technical interface: "is this safe to eat?" is a
/// real question the cook asks. `Recipe` conforms today; a future `PantryIngredient` that
/// carries tagged allergens could conform too.
protocol AllergenDeclaring {
    /// Allergens this item is known to contain. `nil` means the data has not been verified —
    /// never a claim that the item is allergen-free.
    var containsAllergens: Set<DietaryRestriction>? { get }

    /// Whether this item is safe for a cook who must avoid `restrictions`.
    func isSafe(for restrictions: Set<DietaryRestriction>) -> Bool
}

extension AllergenDeclaring {
    /// Fail-closed safety check:
    /// - No restrictions declared → always safe (unverified data is irrelevant).
    /// - Restrictions declared and allergen data is `nil` (unverified) → **not** safe.
    /// - Restrictions declared and allergen data is known → safe only if it shares nothing
    ///   with the restricted set.
    func isSafe(for restrictions: Set<DietaryRestriction>) -> Bool {
        guard !restrictions.isEmpty else { return true }
        guard let containsAllergens else { return false }
        return containsAllergens.isDisjoint(with: restrictions)
    }
}
