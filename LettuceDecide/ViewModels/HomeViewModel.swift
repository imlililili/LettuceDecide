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

    private let confirmedMealStore: ConfirmedMealStoring
    private let shoppingListStore: ShoppingListStoring

    init(confirmedMealStore: ConfirmedMealStoring, shoppingListStore: ShoppingListStoring) {
        self.confirmedMealStore = confirmedMealStore
        self.shoppingListStore = shoppingListStore
        reload()
    }

    var isEmpty: Bool { confirmedMeals.isEmpty }

    func reload() {
        confirmedMeals = confirmedMealStore.loadConfirmedMeals().sorted { $0.date < $1.date }
        shoppingList = shoppingListStore.loadItems().sorted { $0.ingredientName < $1.ingredientName }
    }
}
