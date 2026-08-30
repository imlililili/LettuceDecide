import Foundation

/// The unit a quantity of an ingredient is measured in.
///
/// Real-world meaning: how a cook would describe "how much" — by weight, by volume, or
/// by count. Deliberately a small fixed set for the MVP: cross-unit conversion (grams to
/// cups, say) depends on the density of each specific ingredient, which the app does not
/// model. Two quantities can only be compared or combined when their units are identical.
enum IngredientUnit: String, CaseIterable, Identifiable, Codable {
    case grams
    case millilitres
    case pieces
    case cups
    case tablespoons
    case teaspoons

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .grams: return "g"
        case .millilitres: return "ml"
        case .pieces: return "pcs"
        case .cups: return "cups"
        case .tablespoons: return "tbsp"
        case .teaspoons: return "tsp"
        }
    }

    /// Best-effort mapping from the free-text unit strings Spoonacular returns
    /// (`"gram"`, `"cup"`, `"tablespoons"`, …) onto the fixed MVP set.
    /// Returns `nil` for anything unrecognised — the caller then treats the
    /// quantity as not automatically comparable (see `UpdateInventoryAfterCookingUseCase`).
    init?(spoonacularUnit raw: String) {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "g", "gram", "grams": self = .grams
        case "ml", "milliliter", "milliliters", "millilitre", "millilitres": self = .millilitres
        case "", "piece", "pieces", "x", "serving", "servings": self = .pieces
        case "cup", "cups": self = .cups
        case "tb", "tbs", "tbsp", "tablespoon", "tablespoons": self = .tablespoons
        case "tsp", "teaspoon", "teaspoons": self = .teaspoons
        default: return nil
        }
    }
}
