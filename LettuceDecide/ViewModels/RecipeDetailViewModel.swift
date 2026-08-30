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
    let result: PantryMatchResult

    private let updateInventory: UpdateInventoryAfterCookingUseCase

    @Published var cookAlert: CookAlert?

    struct CookAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        /// Whether the pantry was actually updated (drives "pop back on OK").
        let didCook: Bool
    }

    init(result: PantryMatchResult, pantryStore: PantryStoring) {
        self.result = result
        self.updateInventory = UpdateInventoryAfterCookingUseCase(store: pantryStore)
    }

    var recipe: Recipe { result.recipe }

    var ingredientStatuses: [IngredientStatus] {
        recipe.requiredIngredients.enumerated().map { index, required in
            IngredientStatus(
                id: index,
                name: required.name,
                requiredAmount: "\(number(required.requiredQuantity)) \(required.unit.displayName)",
                kind: kind(for: required)
            )
        }
    }

    func markAsCooked() {
        do {
            let outcome = try updateInventory.execute(result)
            cookAlert = CookAlert(title: "Marked as cooked", message: message(for: outcome), didCook: true)
        } catch let error as InventoryUpdateError {
            cookAlert = CookAlert(
                title: "Couldn't update your pantry",
                message: error.errorDescription ?? "Something went wrong.",
                didCook: false
            )
        } catch {
            cookAlert = CookAlert(title: "Couldn't update your pantry", message: error.localizedDescription, didCook: false)
        }
    }

    private func kind(for required: RecipeIngredient) -> IngredientStatus.Kind {
        let key = required.name.normalizedIngredientName
        guard let owned = result.matchedIngredients.first(where: { $0.ingredientName.normalizedIngredientName == key }) else {
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
