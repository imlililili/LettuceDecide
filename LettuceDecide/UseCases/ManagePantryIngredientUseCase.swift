import Foundation

/// Something that can go wrong when the cook changes their pantry.
enum PantryIngredientError: LocalizedError, Equatable {
    case invalidQuantity(provided: Double)
    case expiryDateAlreadyPassed(date: Date)
    case ingredientNoLongerInPantry(id: UUID)

    var errorDescription: String? {
        switch self {
        case .invalidQuantity(let provided):
            return "Quantity must be greater than zero (you entered \(formatted(provided))). Check the amount and try again."
        case .expiryDateAlreadyPassed(let date):
            let day = date.formatted(date: .abbreviated, time: .omitted)
            return "That expiry date (\(day)) has already passed. If this ingredient has gone off, throw it out instead of adding it to your pantry."
        case .ingredientNoLongerInPantry:
            return "That ingredient isn't in your pantry any more — it may have been used up or removed on another screen."
        }
    }

    private func formatted(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}

/// Business operation: every change the cook makes to their pantry inventory — adding an
/// ingredient, editing an existing line, or removing one.
///
/// One use case with an `Action` rather than three: `add` and `update` share the same
/// validation, and `remove` has no rule of its own, so splitting them would just be three
/// near-empty shells.
///
/// Protects the PRD's "no negative or duplicate inventory" rule:
/// - quantity must be greater than zero (`add` and `update`);
/// - an expiry date in the past is rejected — that is spoiled food, not inventory;
/// - a volume-group quantity (cups/tablespoons/teaspoons) is normalised into millilitres
///   before anything else happens (see `IngredientUnit.normalizedForPantryStorage`) — every
///   write goes through here, whichever screen it came from, so a pantry line only ever ends
///   up in one of three units (grams/pieces/millilitres), never cups/tbsp/tsp;
/// - `add`ing an ingredient that matches an existing line (`PantryIngredient.isSameStock`) is
///   *not* an error: the quantities are merged into the one line and the more urgent
///   (earlier) expiry date is kept;
/// - `update`/`remove` of a line that is already gone: `remove` is a silent no-op (the end
///   state is what the cook wanted); `update` throws `ingredientNoLongerInPantry` because
///   the edit the cook is looking at no longer applies.
struct ManagePantryIngredientUseCase {
    let store: PantryStoring

    enum Action: Equatable {
        case add(
            name: String, quantity: Double, unit: IngredientUnit, storageLocation: StorageLocation,
            expiryDate: Date?, ingredientId: Int? = nil
        )
        case update(id: UUID, quantity: Double, unit: IngredientUnit, storageLocation: StorageLocation, expiryDate: Date?)
        case remove(id: UUID)
    }

    /// - Returns: the full pantry after the change, so callers can refresh their view.
    @discardableResult
    func execute(_ action: Action, now: Date = Date()) throws -> [PantryIngredient] {
        var pantry = store.load()

        switch action {
        case let .add(name, quantity, unit, storageLocation, expiryDate, ingredientId):
            try validate(quantity: quantity, expiryDate: expiryDate, now: now)
            let normalized = IngredientUnit.normalizedForPantryStorage(quantity: quantity, unit: unit)
            let addition = PantryIngredient(
                ingredientName: name.trimmingCharacters(in: .whitespacesAndNewlines),
                quantity: normalized.quantity,
                unit: normalized.unit,
                storageLocation: storageLocation,
                expiryDate: expiryDate,
                dateAdded: now,
                ingredientId: ingredientId
            )
            if let index = pantry.firstIndex(where: { $0.isSameStock(as: addition) }) {
                pantry[index].quantity += normalized.quantity
                pantry[index].expiryDate = earlierExpiry(pantry[index].expiryDate, expiryDate)
            } else {
                pantry.append(addition)
            }

        case let .update(id, quantity, unit, storageLocation, expiryDate):
            try validate(quantity: quantity, expiryDate: expiryDate, now: now)
            guard let index = pantry.firstIndex(where: { $0.id == id }) else {
                throw PantryIngredientError.ingredientNoLongerInPantry(id: id)
            }
            let normalized = IngredientUnit.normalizedForPantryStorage(quantity: quantity, unit: unit)
            pantry[index].quantity = normalized.quantity
            pantry[index].unit = normalized.unit
            pantry[index].storageLocation = storageLocation
            pantry[index].expiryDate = expiryDate

        case let .remove(id):
            pantry.removeAll { $0.id == id }
        }

        store.save(pantry)
        return pantry
    }

    private func validate(quantity: Double, expiryDate: Date?, now: Date) throws {
        guard quantity > 0 else {
            throw PantryIngredientError.invalidQuantity(provided: quantity)
        }
        if let expiryDate {
            let startOfToday = Calendar.current.startOfDay(for: now)
            if Calendar.current.startOfDay(for: expiryDate) < startOfToday {
                throw PantryIngredientError.expiryDateAlreadyPassed(date: expiryDate)
            }
        }
    }

    private func earlierExpiry(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (l?, r?): return min(l, r)
        case let (l?, nil): return l
        case let (nil, r?): return r
        case (nil, nil): return nil
        }
    }
}
