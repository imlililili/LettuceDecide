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
        case "g", "gram", "grams", "gr": self = .grams
        case "ml", "milliliter", "milliliters", "millilitre", "millilitres": self = .millilitres
        case "", "piece", "pieces", "x", "serving", "servings": self = .pieces
        case "cup", "cups", "c": self = .cups
        case "tb", "tbs", "tbsp", "tablespoon", "tablespoons": self = .tablespoons
        case "tsp", "teaspoon", "teaspoons": self = .teaspoons
        default: return nil
        }
    }

    /// Some raw Spoonacular unit strings are a fixed multiple of a unit already in the MVP
    /// set rather than that unit's own string — kilograms are exactly 1000 grams, an
    /// undisputed SI ratio, not a guess. `init(spoonacularUnit:)` alone can't express that (it
    /// only maps a string to a case, with the amount left untouched), so without this a "0.5
    /// kg" or "200 gr" ingredient line fell through to `.pieces` with its amount unchanged —
    /// live-diagnosed as the cause of implausible shopping-list quantities like "potatoes 200
    /// pcs" (the raw line really was 200, just 200 **grams**, not 200 potatoes).
    ///
    /// - Returns: the amount rescaled into the matching MVP unit, or `nil` if `rawUnit` isn't
    ///   one of these fixed-multiple cases (the ordinary `init(spoonacularUnit:)` path handles
    ///   everything else, "gr" included — that one *is* already gram-scaled, just abbreviated).
    static func rescaledAmount(_ rawAmount: Double, rawUnit: String) -> (amount: Double, unit: IngredientUnit)? {
        switch rawUnit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "kg", "kilogram", "kilograms": return (rawAmount * 1000, .grams)
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

    /// Normalises a quantity for storage in the pantry (`ManagePantryIngredientUseCase` calls
    /// this on every write): a volume-group unit — `millilitres`/`cups`/`tablespoons`/
    /// `teaspoons` — becomes millilitres, since converting between them is a fixed,
    /// ingredient-independent ratio with nothing to guess (see `VolumeConversion`). `grams`
    /// and `pieces` come back unchanged — converting *those* would need an ingredient's
    /// density or average item size, which this app does not model, the same "don't guess"
    /// boundary as everywhere else.
    ///
    /// This is why a pantry line only ever exists in one of three units — `grams`, `pieces`,
    /// or `millilitres` — no matter which unit the cook picked when typing it in, or which
    /// unit a recipe originally called for: cups/tablespoons/teaspoons are too imprecise a
    /// way to track inventory long-term (a "cup" of a chopped ingredient packs differently
    /// each time), so they exist only as an input convenience, never as stored state.
    static func normalizedForPantryStorage(quantity: Double, unit: IngredientUnit) -> (quantity: Double, unit: IngredientUnit) {
        guard let millilitres = VolumeConversion.millilitres(for: quantity, unit: unit) else {
            return (quantity, unit)
        }
        return (((millilitres * 100).rounded()) / 100, .millilitres)
    }

    /// Converts `quantity` of `self` into `targetUnit`, or `nil` when that conversion isn't a
    /// safe, ingredient-independent one.
    ///
    /// The single place every "can these two quantities be compared or combined" decision in
    /// the app should go through — comparing a recipe's required amount against a pantry
    /// line's stock (`UpdateInventoryAfterCookingUseCase`, `PantryShortfallCalculator`, the
    /// Recipe Detail checklist), not a second copy of the same reasoning. Reuses
    /// `VolumeConversion` rather than re-deriving it, so the two never drift apart.
    ///
    /// Succeeds when `unit == targetUnit` (trivially), or when both are volume units
    /// (`millilitres`/`cups`/`tablespoons`/`teaspoons`) — a fixed ratio, nothing to guess.
    /// Fails (returns `nil`) for anything crossing `measurementGroup` — weight, volume, and
    /// count each need information this app does not model (an ingredient's density or
    /// average item size) to convert between, and that boundary must never quietly move.
    /// Weight and count are each a single-unit group today, so this only ever does real work
    /// between volume units — but is written generically rather than volume-specific, so a
    /// future unit added to an existing group is handled without another call site to update.
    static func convert(_ quantity: Double, from unit: IngredientUnit, to targetUnit: IngredientUnit) -> Double? {
        if unit == targetUnit { return quantity }
        guard
            let millilitres = VolumeConversion.millilitres(for: quantity, unit: unit),
            let millilitresPerTargetUnit = VolumeConversion.millilitres(for: 1, unit: targetUnit)
        else {
            return nil
        }
        return millilitres / millilitresPerTargetUnit
    }
}
