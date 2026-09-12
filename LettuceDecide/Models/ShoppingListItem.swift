import Foundation

/// One line of the shopping list: an ingredient the cook still needs, in the amount the
/// week's plan (or a single recipe) calls for.
///
/// Real-world meaning: a line the cook would write on a scrap of paper before going to the
/// shop.
///
/// Business rule (dedupe): two lines describe the same purchase — and are merged into one,
/// their quantities combined — when they identify the same ingredient **and** their units
/// belong to the same measurement family (`IngredientUnit.MeasurementGroup`). `mergeKey` is
/// that identity:
/// - **Ingredient identity** prefers Spoonacular's own ingredient `id` (`ingredientId`) over
///   the ingredient name — the same ingredient is worded differently across recipes ("garlic"
///   vs "garlic cloves"), and a stable id survives that where a name string can't. Falls back
///   to the normalised name only when no id is known.
/// - **Measurement family**, not the literal unit: `millilitres`/`cups`/`tablespoons`/
///   `teaspoons` are all volume and freely convert into one another with a fixed,
///   ingredient-independent ratio (see `IngredientUnit.VolumeConversion`), so they merge into
///   one line. `grams` (weight) and `pieces` (count) never merge with volume or each other —
///   that conversion depends on the specific ingredient's density or size, which this app
///   does not model, and guessing would be exactly the kind of silent wrong answer the rest
///   of the app refuses to give.
/// The merge itself is applied by `addMerging`, below.
struct ShoppingListItem: Identifiable, Codable, Equatable {
    let id: UUID
    let ingredientName: String
    var requiredQuantity: Double
    var unit: IngredientUnit
    let dateAdded: Date
    /// Spoonacular's ingredient id, when known. See the merge-identity rule above.
    let ingredientId: Int?
    /// `true` when this line's amount came from a `RecipeIngredient` whose quantity couldn't
    /// be trusted (see `RecipeIngredient.quantityIsUncertain`) — the UI shows an honest
    /// "amount unclear" instead of `requiredQuantity`, and merging never sums an uncertain
    /// amount into another line's number (see `addMerging`).
    var quantityIsUncertain: Bool

    init(
        id: UUID = UUID(),
        ingredientName: String,
        requiredQuantity: Double,
        unit: IngredientUnit,
        dateAdded: Date = Date(),
        ingredientId: Int? = nil,
        quantityIsUncertain: Bool = false
    ) {
        self.id = id
        self.ingredientName = ingredientName
        self.requiredQuantity = requiredQuantity
        self.unit = unit
        self.dateAdded = dateAdded
        self.ingredientId = ingredientId
        self.quantityIsUncertain = quantityIsUncertain
    }

    /// Tolerant of JSON written before `ingredientId`/`quantityIsUncertain` existed (the
    /// persisted shopping list file) — both default to "unknown"/"not flagged" rather than
    /// failing to decode.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        ingredientName = try c.decode(String.self, forKey: .ingredientName)
        requiredQuantity = try c.decode(Double.self, forKey: .requiredQuantity)
        unit = try c.decode(IngredientUnit.self, forKey: .unit)
        dateAdded = try c.decode(Date.self, forKey: .dateAdded)
        ingredientId = try c.decodeIfPresent(Int.self, forKey: .ingredientId)
        quantityIsUncertain = try c.decodeIfPresent(Bool.self, forKey: .quantityIsUncertain) ?? false
    }

    /// Identity for the dedupe rule: see the merge-identity and measurement-family rules
    /// above. Not the same as `id`, which is per-record.
    var mergeKey: MergeKey {
        let identity: MergeKey.Identity = ingredientId.map(MergeKey.Identity.ingredientId)
            ?? .normalizedName(ingredientName.normalizedIngredientName)
        return MergeKey(identity: identity, measurementGroup: unit.measurementGroup)
    }

    struct MergeKey: Hashable {
        let identity: Identity
        let measurementGroup: IngredientUnit.MeasurementGroup

        enum Identity: Hashable {
            case ingredientId(Int)
            case normalizedName(String)
        }
    }
}

extension Array where Element == ShoppingListItem {
    /// Adds `item` under the dedupe rule (see `ShoppingListItem.mergeKey`): an existing line
    /// with the same identity and measurement family gets combined with it; anything else is
    /// appended as a new line.
    ///
    /// Combining two lines:
    /// - if either side's amount is uncertain, the merged line is marked uncertain too and
    ///   its `requiredQuantity` is left alone — a bad number must never get compounded into a
    ///   good one to look more confident than it is;
    /// - otherwise, if the units are identical, the quantities are simply added (the original
    ///   behaviour — still how `grams` and `pieces` lines combine, since each of those
    ///   measurement groups only ever contains one unit);
    /// - otherwise (same measurement group, different literal units — only possible within
    ///   the volume group), both amounts are converted to millilitres, summed, and the total
    ///   is re-expressed in whichever of cups/tablespoons/teaspoons reads best (see
    ///   `IngredientUnit.VolumeConversion.displayForm`). Each merge rounds its running total
    ///   to 2 decimal places before the *next* line folds in, so three or more volume lines
    ///   merged in sequence can drift a fraction of a percent from a single-shot sum of all of
    ///   them — well inside "kitchen approximation", the same standing as the 240/15/5ml
    ///   ratios themselves, not a correctness bug.
    ///
    /// Shared by `WeeklyPlanBuilder` (aggregating a week's shortfalls) and
    /// `AddMissingIngredientsToShoppingListUseCase` (merging into the saved list).
    mutating func addMerging(_ item: ShoppingListItem) {
        guard let index = firstIndex(where: { $0.mergeKey == item.mergeKey }) else {
            append(item)
            return
        }

        if self[index].quantityIsUncertain || item.quantityIsUncertain {
            self[index].quantityIsUncertain = true
            return
        }

        if self[index].unit == item.unit {
            self[index].requiredQuantity += item.requiredQuantity
            return
        }

        guard
            let existingML = IngredientUnit.VolumeConversion.millilitres(for: self[index].requiredQuantity, unit: self[index].unit),
            let incomingML = IngredientUnit.VolumeConversion.millilitres(for: item.requiredQuantity, unit: item.unit)
        else {
            // The measurement group matched but the volume conversion didn't apply to both
            // sides — shouldn't happen (weight/count groups hold exactly one unit each, so a
            // unit mismatch within a matched group implies volume), but never guess: keep
            // this as its own line rather than silently combining unlike amounts.
            append(item)
            return
        }

        let (quantity, unit) = IngredientUnit.VolumeConversion.displayForm(millilitres: existingML + incomingML)
        self[index].requiredQuantity = quantity
        self[index].unit = unit
    }
}
