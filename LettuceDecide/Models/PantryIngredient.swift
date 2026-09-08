import Foundation

/// One line of the cook's fridge / freezer / pantry inventory: a specific ingredient, in a
/// specific place, in a specific amount, that may spoil.
///
/// Real-world meaning: a single item the cook would point at and say "I have this".
///
/// Business rules:
/// - `quantity` is always greater than zero. A line with zero or negative quantity is not
///   inventory, it is a data error, and `ManagePantryIngredientUseCase` rejects it.
/// - Two lines that share the same normalised name, unit, and storage location describe the
///   same physical stock and must be merged into one line (their quantities added), never
///   stored side by side. `mergeKey` is that identity.
struct PantryIngredient: Identifiable, Codable, Equatable {
    let id: UUID
    let ingredientName: String
    var quantity: Double
    var unit: IngredientUnit
    var storageLocation: StorageLocation
    var expiryDate: Date?
    let dateAdded: Date

    init(
        id: UUID = UUID(),
        ingredientName: String,
        quantity: Double,
        unit: IngredientUnit,
        storageLocation: StorageLocation,
        expiryDate: Date? = nil,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.ingredientName = ingredientName
        self.quantity = quantity
        self.unit = unit
        self.storageLocation = storageLocation
        self.expiryDate = expiryDate
        self.dateAdded = dateAdded
    }

    /// Identity for the "same physical stock" merge rule: normalised name + unit + location.
    /// Not the same as `id`, which is per-record.
    var mergeKey: MergeKey {
        MergeKey(
            normalizedName: ingredientName.normalizedIngredientName,
            unit: unit,
            storageLocation: storageLocation
        )
    }

    /// Expiry classification as of a given moment (default: now).
    func expiryStatus(asOf now: Date = Date()) -> ExpiryStatus {
        ExpiryStatus(expiryDate: expiryDate, asOf: now)
    }

    struct MergeKey: Hashable {
        let normalizedName: String
        let unit: IngredientUnit
        let storageLocation: StorageLocation
    }
}

extension String {
    /// Normalised form used to decide whether two ingredient names refer to the same thing:
    /// lowercased, whitespace-collapsed, and crudely de-pluralised. Best-effort only — it
    /// treats "tomatoes"/"tomato" and "berries"/"berry" as equal but will not catch every
    /// irregular plural. Used for the pantry merge rule and for matching Spoonacular's
    /// ingredient names back onto pantry lines.
    var normalizedIngredientName: String {
        let lowered = lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsed = lowered.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        if collapsed.hasSuffix("ies"), collapsed.count > 3 {
            return String(collapsed.dropLast(3)) + "y"
        }
        if collapsed.hasSuffix("es"), collapsed.count > 3 {
            return String(collapsed.dropLast(2))
        }
        if collapsed.hasSuffix("s"), collapsed.count > 2 {
            return String(collapsed.dropLast(1))
        }
        return collapsed
    }
}
