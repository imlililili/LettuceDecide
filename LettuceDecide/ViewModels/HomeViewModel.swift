import Foundation
import Combine

/// The Home dashboard: every meal the cook has confirmed from the Week Plan, and the
/// persisted shopping list built from confirming them.
///
/// Deliberately just a reload-on-demand read of two stores, not a live subscription —
/// confirming happens on a different tab's `NavigationStack` (Calendar → Week Plan → Recipe
/// Detail), so there's no in-place pantry-style `changes` publisher to react to here.
/// `MainTabView` reloads this when the cook switches to the Home tab; `onCooked` reloads it
/// after marking a confirmed meal cooked from within Home's own stack.
@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var confirmedMeals: [ConfirmedMeal] = []
    @Published private(set) var shoppingList: [ShoppingListItem] = []

    /// A shopping-list line the cook just swiped "Bought" on whose amount isn't trustworthy
    /// (see `ShoppingListItem.quantityIsUncertain`) — drives a confirm-amount sheet in
    /// `HomeView`. `nil` means no sheet is showing.
    @Published var pendingUncertainPurchase: ShoppingListItem?
    @Published var errorMessage: String?

    private let confirmedMealStore: ConfirmedMealStoring
    private let shoppingListStore: ShoppingListStoring
    private let purchaseItem: PurchaseShoppingListItemUseCase

    init(confirmedMealStore: ConfirmedMealStoring, shoppingListStore: ShoppingListStoring, pantryStore: PantryStoring) {
        self.confirmedMealStore = confirmedMealStore
        self.shoppingListStore = shoppingListStore
        self.purchaseItem = PurchaseShoppingListItemUseCase(shoppingListStore: shoppingListStore, pantryStore: pantryStore)
        reload()
    }

    var isEmpty: Bool { confirmedMeals.isEmpty }

    func reload() {
        confirmedMeals = confirmedMealStore.loadConfirmedMeals().sorted { $0.date < $1.date }
        shoppingList = shoppingListStore.loadItems().sorted { $0.ingredientName < $1.ingredientName }
    }

    /// The cook marked `item` as bought. A trustworthy amount goes straight into the pantry;
    /// an uncertain one opens the confirm-amount sheet instead of writing a number nobody
    /// actually believes (see `PurchaseShoppingListItemUseCase`).
    func markAsBought(_ item: ShoppingListItem) {
        guard !item.quantityIsUncertain else {
            pendingUncertainPurchase = item
            return
        }
        do {
            try purchaseItem.execute(item)
            reload()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// The cook entered a real amount for a previously-uncertain item in the confirm-amount
    /// sheet.
    func confirmUncertainPurchase(quantity: Double, unit: IngredientUnit) {
        guard let item = pendingUncertainPurchase else { return }
        do {
            try purchaseItem.execute(item, confirmedQuantity: quantity, confirmedUnit: unit)
            reload()
            pendingUncertainPurchase = nil
        } catch {
            // Leave the sheet open so the cook can see the error and correct the amount —
            // dismissing here would silently drop what they just typed.
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func cancelUncertainPurchase() {
        pendingUncertainPurchase = nil
    }
}
