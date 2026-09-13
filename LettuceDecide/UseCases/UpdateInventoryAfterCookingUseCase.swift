import Foundation

/// Something that can go wrong when deducting a cooked recipe from the pantry.
enum InventoryUpdateError: LocalizedError, Equatable {
    case insufficientQuantity(ingredientName: String, available: Double, requested: Double)
    case ingredientNotFound(name: String)

    var errorDescription: String? {
        switch self {
        case .insufficientQuantity(let name, let available, let requested):
            return "You only have \(trimmed(available)) of \(name), but this recipe needs \(trimmed(requested)). Update your pantry first if you already used more than recorded."
        case .ingredientNotFound(let name):
            return "\(name) isn't in your pantry any more. It may have already been used or removed."
        }
    }

    private func trimmed(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}

/// What happened when a recipe was marked as cooked.
struct InventoryUpdateOutcome: Equatable {
    /// Names of pantry lines whose quantity was reduced (or that were used up entirely).
    let deducted: [String]
    /// Recipe ingredients the cook has to reconcile by hand because the recipe measures them
    /// in a unit that can't be safely converted into what the pantry stores them in (see
    /// `IngredientUnit.convert`) — e.g. the recipe wants grams and the pantry has it in
    /// pieces. A same-*measurement-group* mismatch (the recipe in tablespoons, the pantry in
    /// millilitres) is converted and deducted normally, not flagged here.
    let needsManualReview: [RecipeIngredient]
}

/// Business operation: when the cook finishes a recommended recipe, take the ingredients it
/// used out of the pantry.
///
/// Protects PRD requirement #9 — inventory must never go negative.
///
/// Rules:
/// - only the pantry lines the recommendation actually matched are touched;
/// - a line that has been removed since the recommendation was shown throws
///   `ingredientNotFound` (the whole update is abandoned, nothing is saved);
/// - if the recipe's unit for an ingredient can't be converted into the pantry's unit for it
///   (`IngredientUnit.convert` — different `measurementGroup`, e.g. grams vs pieces), that
///   ingredient is skipped and reported in `needsManualReview` — still no guessing there. A
///   same-group mismatch (the recipe in tablespoons, the pantry storing it in millilitres) is
///   a safe, ingredient-independent conversion and is deducted normally;
/// - if the recipe's own quantity for an ingredient is flagged uncertain (see
///   `RecipeIngredient.quantityIsUncertain`), it is likewise skipped into
///   `needsManualReview` rather than deducted — a fabricated number must never take real
///   stock out of the pantry;
/// - if a deduction would take a line below zero it throws `insufficientQuantity` and
///   nothing is saved;
/// - a line that reaches exactly zero is removed.
struct UpdateInventoryAfterCookingUseCase {
    let store: PantryStoring

    @discardableResult
    func execute(_ result: PantryMatchResult) throws -> InventoryUpdateOutcome {
        var pantry = store.load()
        var deducted: [String] = []
        var needsReview: [RecipeIngredient] = []

        for matched in result.matchedIngredients {
            guard let index = pantry.firstIndex(where: { $0.id == matched.id }) else {
                throw InventoryUpdateError.ingredientNotFound(name: matched.ingredientName)
            }
            let line = pantry[index]

            guard let required = requiredIngredient(for: line, in: result.recipe) else {
                continue
            }
            guard !required.quantityIsUncertain else {
                needsReview.append(required)
                continue
            }
            guard let requiredInPantryUnit = IngredientUnit.convert(required.requiredQuantity, from: required.unit, to: line.unit) else {
                needsReview.append(required)
                continue
            }

            let remaining = line.quantity - requiredInPantryUnit
            if remaining < 0 {
                throw InventoryUpdateError.insufficientQuantity(
                    ingredientName: line.ingredientName,
                    available: line.quantity,
                    requested: requiredInPantryUnit
                )
            }

            if remaining == 0 {
                pantry.remove(at: index)
            } else {
                pantry[index].quantity = remaining
            }
            deducted.append(line.ingredientName)
        }

        store.save(pantry)
        return InventoryUpdateOutcome(deducted: deducted, needsManualReview: needsReview)
    }

    private func requiredIngredient(for pantryLine: PantryIngredient, in recipe: Recipe) -> RecipeIngredient? {
        let key = pantryLine.ingredientName.normalizedIngredientName
        return recipe.requiredIngredients.first { $0.name.normalizedIngredientName == key }
    }
}
