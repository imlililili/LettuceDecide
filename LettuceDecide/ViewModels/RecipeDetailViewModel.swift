import Foundation
import Combine

/// One line of the Recipe Detail ingredient checklist.
///
/// The recommendation's match percentage only knows whether an ingredient is *present*, so
/// this screen is where the cook is told the honest per-ingredient truth: have enough, have
/// but not enough, or don't have it at all.
struct IngredientStatus: Identifiable, Equatable {
    let id: Int
    let name: String
    /// The amount the recipe calls for, e.g. "2 cups", "16 pcs" — always shown so no line
    /// is left with a blank or vague quantity.
    let requiredAmount: String
    let kind: Kind

    enum Kind: Equatable {
        case have
        case shortBy(have: Double, unit: IngredientUnit)
        case missing
    }
}

@MainActor
final class RecipeDetailViewModel: ObservableObject {
    let recipe: Recipe

    private let pantryStore: PantryStoring
    private let updateInventory: UpdateInventoryAfterCookingUseCase
    private let addToShoppingList: AddMissingIngredientsToShoppingListUseCase
    private var pantryChangeCancellable: AnyCancellable?

    /// The pantry as it stands now. Refreshed whenever the store announces a change, so the
    /// checklist re-derives against live inventory — if the cook adds a missing ingredient
    /// on the Pantry tab and comes back, the ticks are already right.
    @Published private var pantry: [PantryIngredient]

    @Published var notice: Notice?

    struct Notice: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        /// Whether tapping OK should pop the screen (true only after a successful cook).
        let dismissPops: Bool
    }

    init(
        recipe: Recipe,
        pantryStore: PantryStoring,
        addToShoppingList: AddMissingIngredientsToShoppingListUseCase
    ) {
        self.recipe = recipe
        self.pantryStore = pantryStore
        self.updateInventory = UpdateInventoryAfterCookingUseCase(store: pantryStore)
        self.addToShoppingList = addToShoppingList
        self.pantry = pantryStore.load()
        pantryChangeCancellable = pantryStore.changes
            .sink { [weak self] in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.pantry = self.pantryStore.load()
                }
            }
    }

    /// The recipe matched against the current pantry — recomputed on every access, so it
    /// always reflects `pantry` as it stands.
    private var currentMatch: PantryMatchResult {
        .matching(recipe, against: pantry)
    }

    var ingredientStatuses: [IngredientStatus] {
        let matched = currentMatch.matchedIngredients
        return recipe.requiredIngredients.enumerated().map { index, required in
            IngredientStatus(
                id: index,
                name: required.name,
                requiredAmount: "\(number(required.requiredQuantity)) \(required.unit.displayName)",
                kind: kind(for: required, ownedLines: matched)
            )
        }
    }

    /// The recipe ingredients the pantry doesn't currently cover — what an "add to shopping
    /// list" action would add.
    var missingIngredients: [RecipeIngredient] {
        currentMatch.missingIngredients
    }

    func markAsCooked() {
        do {
            let outcome = try updateInventory.execute(currentMatch)
            notice = Notice(title: "Marked as cooked", message: message(for: outcome), dismissPops: true)
        } catch let error as InventoryUpdateError {
            notice = Notice(
                title: "Couldn't update your pantry",
                message: error.errorDescription ?? "Something went wrong.",
                dismissPops: false
            )
        } catch {
            notice = Notice(title: "Couldn't update your pantry", message: error.localizedDescription, dismissPops: false)
        }
    }

    func addMissingToShoppingList() {
        let missing = missingIngredients
        guard !missing.isEmpty else { return }
        addToShoppingList.execute(missing: missing)
        let names = missing.map(\.name)
        notice = Notice(
            title: "Added to your shopping list",
            message: "\(list(names)) — \(missing.count == 1 ? "1 item" : "\(missing.count) items").",
            dismissPops: false
        )
    }

    private func kind(for required: RecipeIngredient, ownedLines: [PantryIngredient]) -> IngredientStatus.Kind {
        let key = required.name.normalizedIngredientName
        guard let owned = ownedLines.first(where: { $0.ingredientName.normalizedIngredientName == key }) else {
            return .missing
        }
        if owned.unit == required.unit, owned.quantity < required.requiredQuantity {
            return .shortBy(have: owned.quantity, unit: required.unit)
        }
        return .have
    }

    private func number(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }

    private func message(for outcome: InventoryUpdateOutcome) -> String {
        var parts: [String] = []
        if !outcome.deducted.isEmpty {
            parts.append("Took \(list(outcome.deducted)) out of your pantry.")
        }
        if !outcome.needsManualReview.isEmpty {
            let names = outcome.needsManualReview.map(\.name)
            parts.append("This recipe measures \(list(names)) differently from your pantry, so update \(names.count == 1 ? "it" : "them") by hand.")
        }
        if parts.isEmpty {
            parts.append("Nothing in your pantry needed changing.")
        }
        return parts.joined(separator: "\n\n")
    }

    private func list(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        case 2: return "\(items[0]) and \(items[1])"
        default: return items.dropLast().joined(separator: ", ") + ", and " + items[items.count - 1]
        }
    }
}
