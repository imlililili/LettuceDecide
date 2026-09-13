import Foundation
import Combine

/// The Home dashboard: every meal the cook has confirmed from the Week Plan, and the
/// persisted shopping list built from confirming them.
///
/// `MainTabView` also reloads this when the cook switches to the Home tab (covers changes made
/// on another tab, e.g. confirming a day from Calendar → Week Plan). The `confirmedMealStore`
/// subscription below covers changes made from *within* Home's own `NavigationStack` — Recipe
/// Detail pushed from a confirmed-meal card doesn't always pop back on "Mark as Cooked" (a
/// manual-review notice keeps the screen open), so a plain "reload when the screen reappears"
/// rule would miss those. Same pattern as `PantryStoring.changes`.
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
    private var confirmedMealChangeCancellable: AnyCancellable?

    init(confirmedMealStore: ConfirmedMealStoring, shoppingListStore: ShoppingListStoring, pantryStore: PantryStoring) {
        self.confirmedMealStore = confirmedMealStore
        self.shoppingListStore = shoppingListStore
        self.purchaseItem = PurchaseShoppingListItemUseCase(shoppingListStore: shoppingListStore, pantryStore: pantryStore)
        reload()

        confirmedMealChangeCancellable = confirmedMealStore.changes
            .sink { [weak self] in
                MainActor.assumeIsolated {
                    self?.reload()
                }
            }
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
