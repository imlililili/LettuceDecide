import Foundation

/// Something that can go wrong when a cook records a pantry ingredient.
enum PantryIngredientError: LocalizedError, Equatable {
    case invalidQuantity(provided: Double)
    case expiryDateAlreadyPassed(date: Date)

    var errorDescription: String? {
        switch self {
        case .invalidQuantity(let provided):
            return "Quantity must be greater than zero (you entered \(formatted(provided))). Check the amount and try again."
        case .expiryDateAlreadyPassed(let date):
            let day = date.formatted(date: .abbreviated, time: .omitted)
            return "That expiry date (\(day)) has already passed. If this ingredient has gone off, throw it out instead of adding it to your pantry."
        }
    }

    private func formatted(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}

/// Business operation: a cook records an ingredient they have, or tops up the amount of one
/// they already recorded.
///
/// Protects the PRD's "no negative or duplicate inventory" rule:
/// - quantity must be greater than zero;
/// - an expiry date in the past is rejected (that is spoiled food, not inventory);
/// - adding an ingredient that matches an existing line by name + unit + location is *not*
///   an error — the quantities are merged into the one line, silently, and the more urgent
///   (earlier) expiry date is kept.
struct AddPantryIngredientUseCase {
    let store: PantryStoring

    /// - Returns: the full pantry after the addition, so callers can refresh their view.
    @discardableResult
    func execute(
        name: String,
        quantity: Double,
        unit: IngredientUnit,
        storageLocation: StorageLocation,
        expiryDate: Date? = nil,
        now: Date = Date()
    ) throws -> [PantryIngredient] {
        guard quantity > 0 else {
            throw PantryIngredientError.invalidQuantity(provided: quantity)
        }
        if let expiryDate {
            let startOfToday = Calendar.current.startOfDay(for: now)
            if Calendar.current.startOfDay(for: expiryDate) < startOfToday {
                throw PantryIngredientError.expiryDateAlreadyPassed(date: expiryDate)
            }
        }

        let addition = PantryIngredient(
            ingredientName: name.trimmingCharacters(in: .whitespacesAndNewlines),
            quantity: quantity,
            unit: unit,
            storageLocation: storageLocation,
            expiryDate: expiryDate,
            dateAdded: now
        )

        var pantry = store.load()
        if let index = pantry.firstIndex(where: { $0.mergeKey == addition.mergeKey }) {
            pantry[index].quantity += quantity
            pantry[index].expiryDate = earlierExpiry(pantry[index].expiryDate, expiryDate)
        } else {
            pantry.append(addition)
        }
        store.save(pantry)
        return pantry
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
