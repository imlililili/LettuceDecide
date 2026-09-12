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
        case "cup", "cups", "c": self = .cups
        case "tb", "tbs", "tbsp", "tablespoon", "tablespoons": self = .tablespoons
        case "tsp", "teaspoon", "teaspoons": self = .teaspoons
        default: return nil
        }
    }

    /// The measurement family this unit belongs to. Units in the same group have a fixed,
    /// undisputed conversion between them — no ingredient-specific density or size needed —
    /// so a shopping list may safely combine them into one line (see
    /// `IngredientUnit.VolumeConversion`). Units in *different* groups never merge: grams,
    /// millilitres, and pieces all need information this app does not have (density, item
    /// size) to convert between them, and guessing is exactly what the MVP design ruled out.
    enum MeasurementGroup: Hashable {
        case weight
        case volume
        case count
    }

    var measurementGroup: MeasurementGroup {
        switch self {
        case .grams: return .weight
        case .millilitres, .cups, .tablespoons, .teaspoons: return .volume
        case .pieces: return .count
        }
    }

    /// Fixed, ingredient-independent volume equivalents — kitchen-measuring-cup
    /// approximations (not scientifically exact figures), the same order of magnitude
    /// Spoonacular's own recipes use. Kept as one clearly-named place so the ratios, or the
    /// set of volume units, only ever need changing in one spot.
    enum VolumeConversion {
        static let millilitresPerCup = 240.0
        static let millilitresPerTablespoon = 15.0
        static let millilitresPerTeaspoon = 5.0

        /// `quantity` of `unit` expressed in millilitres, or `nil` if `unit` isn't a volume
        /// unit (`.grams`, `.pieces`) — those must never be silently folded into a volume
        /// total.
        static func millilitres(for quantity: Double, unit: IngredientUnit) -> Double? {
            switch unit {
            case .millilitres: return quantity
            case .cups: return quantity * millilitresPerCup
            case .tablespoons: return quantity * millilitresPerTablespoon
            case .teaspoons: return quantity * millilitresPerTeaspoon
            case .grams, .pieces: return nil
            }
        }

        /// Picks a human-readable `(quantity, unit)` for an amount already expressed in
        /// millilitres: cups once there's at least a full cup, tablespoons once there's at
        /// least a full tablespoon, teaspoons otherwise. Rounded to 2 decimal places so a
        /// merge never prints something like "1.333333 cups".
        static func displayForm(millilitres: Double) -> (quantity: Double, unit: IngredientUnit) {
            let quantity: Double
            let unit: IngredientUnit
            if millilitres >= millilitresPerCup {
                quantity = millilitres / millilitresPerCup
                unit = .cups
            } else if millilitres >= millilitresPerTablespoon {
                quantity = millilitres / millilitresPerTablespoon
                unit = .tablespoons
            } else {
                quantity = millilitres / millilitresPerTeaspoon
                unit = .teaspoons
            }
            return (((quantity * 100).rounded()) / 100, unit)
        }
    }
}
