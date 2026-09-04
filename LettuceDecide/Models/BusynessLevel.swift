import Foundation

/// How much time and attention the cook realistically has for cooking on a given day.
///
/// Real-world meaning: the difference between "I have an evening free" and "I get twenty
/// minutes between things". This is the single vocabulary both entry points read from — the
/// daily quick-pick on the Recommendations screen and the 7-day weekly planner — so a change
/// to what "busy" means only has to happen in one place.
///
/// Business rule — busyness maps to a hard recipe constraint (see `permits(_:)`), it is not
/// a decorative label:
///
/// | Level     | Max `readyInMinutes` | Max required ingredients |
/// |-----------|----------------------|--------------------------|
/// | `.relaxed`| no cap               | no cap                   |
/// | `.normal` | ≤ 40                 | no cap                   |
/// | `.busy`   | ≤ 20                 | ≤ 5                      |
enum BusynessLevel: String, CaseIterable, Identifiable, Codable {
    case relaxed
    case normal
    case busy

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .relaxed: return "Relaxed"
        case .normal: return "Normal"
        case .busy: return "Busy"
        }
    }

    /// Longest total cooking time this level tolerates, or `nil` for no cap.
    var maxReadyInMinutes: Int? {
        switch self {
        case .relaxed: return nil
        case .normal: return 40
        case .busy: return 20
        }
    }

    /// Largest required-ingredient count this level tolerates, or `nil` for no cap.
    var maxRequiredIngredientCount: Int? {
        switch self {
        case .relaxed, .normal: return nil
        case .busy: return 5
        }
    }

    /// Whether `recipe` fits inside this level's time and effort budget.
    ///
    /// Fail-closed on unknown cooking time: when this level caps `readyInMinutes` and the
    /// recipe does not report one, the recipe is **not** permitted. Same conservative stance
    /// as the allergen rule (`AllergenDeclaring.isSafe(for:)`) — an unknown is treated as a
    /// no, not waved through to fill a slot.
    func permits(_ recipe: Recipe) -> Bool {
        if let maxReadyInMinutes {
            guard let ready = recipe.readyInMinutes, ready <= maxReadyInMinutes else {
                return false
            }
        }
        if let maxRequiredIngredientCount,
           recipe.requiredIngredients.count > maxRequiredIngredientCount {
            return false
        }
        return true
    }
}
