import Foundation

/// Something that can go wrong when marking a shopping-list item as bought.
enum PurchaseShoppingListItemError: LocalizedError, Equatable {
    /// The item's own amount was never trustworthy (see `ShoppingListItem.quantityIsUncertain`
    /// — e.g. Spoonacular's raw unit was "servings", not a real count) and no confirmed
    /// amount was supplied to replace it. Writing that number into the pantry as if it were
    /// real inventory would be exactly the kind of confident-looking wrong answer this app
    /// refuses elsewhere.
    case quantityConfirmationRequired(ingredientName: String)

    var errorDescription: String? {
        switch self {
        case .quantityConfirmationRequired(let name):
            return "The amount for \(name) wasn't clear from the recipe. Enter how much you actually bought."
        }
    }
}

/// Business operation: the cook marks one shopping-list line as bought. Two things happen,
/// as one unit — never one without the other:
/// 1. the ingredient (and its quantity) is added into the pantry, merging into an existing
///    matching line the same way any other pantry addition does
///    (`ManagePantryIngredientUseCase`, which is also what "buying more of something you
///    already have" accumulates onto rather than overwrites);
/// 2. the line is removed from the shopping list.
///
/// The pantry write happens *first*, and the shopping-list removal only after it succeeds —
/// so a validation failure (or an uncertain amount with nothing to replace it) never loses the
/// line: it simply stays on the list, unchanged, for the cook to try again.
///
/// `ingredientId` (when the shopping-list line has one) flows through to the new
/// `PantryIngredient`, so this pantry line can later be identified just as reliably as the
/// shopping list itself does (see `ShoppingListItem.isSamePurchase(as:)` /
/// `PantryIngredient.isSameStock(as:)`) — not degraded back to name-only matching just
/// because it crossed from one list to the other.
struct PurchaseShoppingListItemUseCase {
    let shoppingListStore: ShoppingListStoring
    let pantryStore: PantryStoring

    /// - Parameters:
    ///   - item: the shopping-list line being bought.
    ///   - confirmedQuantity/confirmedUnit: the cook's own entered amount. Required (both, or
    ///     neither) when `item.quantityIsUncertain` — otherwise this throws
    ///     `quantityConfirmationRequired` rather than trusting `item.requiredQuantity`. Optional
    ///     for an already-trustworthy item, where they default to the item's own amount.
    ///   - storageLocation: where the cook is putting it — defaults to `.fridge`, matching
    ///     `IngredientDraft`'s own default for a freshly added ingredient.
    @discardableResult
    func execute(
        _ item: ShoppingListItem,
        confirmedQuantity: Double? = nil,
        confirmedUnit: IngredientUnit? = nil,
        storageLocation: StorageLocation = .fridge,
        expiryDate: Date? = nil,
        now: Date = Date()
    ) throws -> [PantryIngredient] {
        let quantity: Double
        let unit: IngredientUnit
        if item.quantityIsUncertain {
            guard let confirmedQuantity, let confirmedUnit else {
                throw PurchaseShoppingListItemError.quantityConfirmationRequired(ingredientName: item.ingredientName)
            }
            quantity = confirmedQuantity
            unit = confirmedUnit
        } else {
            quantity = confirmedQuantity ?? item.requiredQuantity
            unit = confirmedUnit ?? item.unit
        }

        let pantry = try ManagePantryIngredientUseCase(store: pantryStore).execute(
            .add(
                name: item.ingredientName,
                quantity: quantity,
                unit: unit,
                storageLocation: storageLocation,
                expiryDate: expiryDate,
                ingredientId: item.ingredientId
            ),
            now: now
        )

        var list = shoppingListStore.loadItems()
        list.removeAll { $0.id == item.id }
        shoppingListStore.save(list)

        return pantry
    }
}
