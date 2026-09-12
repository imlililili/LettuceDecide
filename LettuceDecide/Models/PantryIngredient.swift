import Foundation

/// One line of the cook's fridge / freezer / pantry inventory: a specific ingredient, in a
/// specific place, in a specific amount, that may spoil.
///
/// Real-world meaning: a single item the cook would point at and say "I have this".
///
/// Business rules:
/// - `quantity` is always greater than zero. A line with zero or negative quantity is not
///   inventory, it is a data error, and `ManagePantryIngredientUseCase` rejects it.
/// - Two lines that describe the same physical stock — see `isSameStock(as:)` — must be
///   merged into one line (their quantities added), never stored side by side.
struct PantryIngredient: Identifiable, Codable, Equatable {
    let id: UUID
    let ingredientName: String
    var quantity: Double
    var unit: IngredientUnit
    var storageLocation: StorageLocation
    var expiryDate: Date?
    let dateAdded: Date
    /// Spoonacular's ingredient id, when the line originated from a recipe (e.g. bought off
    /// the shopping list via `PurchaseShoppingListItemUseCase`) rather than typed in by hand.
    /// See `isSameStock(as:)` for how this is used.
    let ingredientId: Int?

    init(
        id: UUID = UUID(),
        ingredientName: String,
        quantity: Double,
        unit: IngredientUnit,
        storageLocation: StorageLocation,
        expiryDate: Date? = nil,
        dateAdded: Date = Date(),
        ingredientId: Int? = nil
    ) {
        self.id = id
        self.ingredientName = ingredientName
        self.quantity = quantity
        self.unit = unit
        self.storageLocation = storageLocation
        self.expiryDate = expiryDate
        self.dateAdded = dateAdded
        self.ingredientId = ingredientId
    }

    /// Tolerant of JSON written before `ingredientId` existed (the persisted pantry file) —
    /// missing means "typed in by hand / unknown", not a decode failure.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        ingredientName = try c.decode(String.self, forKey: .ingredientName)
        quantity = try c.decode(Double.self, forKey: .quantity)
        unit = try c.decode(IngredientUnit.self, forKey: .unit)
        storageLocation = try c.decode(StorageLocation.self, forKey: .storageLocation)
        expiryDate = try c.decodeIfPresent(Date.self, forKey: .expiryDate)
        dateAdded = try c.decode(Date.self, forKey: .dateAdded)
        ingredientId = try c.decodeIfPresent(Int.self, forKey: .ingredientId)
    }

    /// Whether `self` and `other` describe the same physical stock — same rule shape as
    /// `ShoppingListItem.isSamePurchase(as:)`: a matching known `ingredientId` OR a matching
    /// normalised name is sufficient (neither is reliable alone — see that method's docs for
    /// the live-diagnosed reason), **and** the same unit and storage location, since a fridge
    /// stash and a freezer stash of the same ingredient are genuinely separate lines. This
    /// compares whatever units the two lines actually hold — it does not itself convert
    /// cups/tbsp/tsp into millilitres. In practice that never causes a spurious split, because
    /// every write that reaches here has already gone through
    /// `IngredientUnit.normalizedForPantryStorage` (`ManagePantryIngredientUseCase` calls it
    /// before ever constructing or comparing a `PantryIngredient`), so a pantry line's `unit`
    /// is always one of `grams`/`pieces`/`millilitres` to begin with — never cups/tbsp/tsp.
    /// Grams and pieces still never merge with millilitres or each other here: that
    /// conversion needs an ingredient's density or average item size, which this app does not
    /// model, and pantry inventory numbers feed real deductions
    /// (`UpdateInventoryAfterCookingUseCase`), so this stays exact-match only.
    func isSameStock(as other: PantryIngredient) -> Bool {
        guard unit == other.unit, storageLocation == other.storageLocation else { return false }
        if let lhsID = ingredientId, let rhsID = other.ingredientId, lhsID == rhsID {
            return true
        }
        return ingredientName.normalizedIngredientName == other.ingredientName.normalizedIngredientName
    }

    /// Expiry classification as of a given moment (default: now).
    func expiryStatus(asOf now: Date = Date()) -> ExpiryStatus {
        ExpiryStatus(expiryDate: expiryDate, asOf: now)
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
