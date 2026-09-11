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

/// Where the cook opened this recipe from — the two entry points mean two different things by
/// "yes, this one":
///
/// - `.weekPlan(date:)`: this is a day in the Weekly Planner's preview — a plan for a day that
///   may not have happened yet. Choosing it only means "yes, I'd like to have this that day";
///   it must not touch the pantry, because nothing has actually been cooked. Only once `date`
///   has arrived does "Mark as Cooked" become an honest, available action here too.
/// - `.confirmed(date:)`: this is a meal the cook already confirmed, opened from the Home
///   dashboard. There's nothing left to confirm — the only question is whether `date` has
///   arrived yet, exactly the same date-gating rule as `.weekPlan` uses for "Mark as Cooked".
enum RecipeDetailContext: Equatable {
    case weekPlan(date: Date)
    case confirmed(date: Date)
}

@MainActor
final class RecipeDetailViewModel: ObservableObject {
    let recipe: Recipe
    let context: RecipeDetailContext

    private let pantryStore: PantryStoring
    private let updateInventory: UpdateInventoryAfterCookingUseCase
    private let addToShoppingList: AddMissingIngredientsToShoppingListUseCase
    private let confirmPlannedMealUseCase: ConfirmPlannedMealUseCase
    private let now: Date
    private var pantryChangeCancellable: AnyCancellable?

    /// The pantry as it stands now. Refreshed whenever the store announces a change, so the
    /// checklist re-derives against live inventory — if the cook adds a missing ingredient
    /// on the Pantry tab and comes back, the ticks are already right.
    @Published private var pantry: [PantryIngredient]

    /// Set once the cook confirms a `.weekPlan` day's recipe — mirrors what
    /// `ConfirmPlannedMealUseCase` just durably recorded via `ConfirmedMealStoring`. It exists
    /// on the view model too (rather than being re-derived from the store on every render) so
    /// the screen can say "planned" back to the cook and disable a re-tap without a reload.
    @Published private(set) var isConfirmedForPlan = false

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
        addToShoppingList: AddMissingIngredientsToShoppingListUseCase,
        confirmedMealStore: ConfirmedMealStoring,
        context: RecipeDetailContext,
        now: Date = Date()
    ) {
        self.recipe = recipe
        self.pantryStore = pantryStore
        self.updateInventory = UpdateInventoryAfterCookingUseCase(store: pantryStore)
        self.addToShoppingList = addToShoppingList
        self.confirmPlannedMealUseCase = ConfirmPlannedMealUseCase(
            confirmedMealStore: confirmedMealStore,
            pantryStore: pantryStore,
            addToShoppingList: addToShoppingList
        )
        self.context = context
        self.now = now
        self.pantry = pantryStore.load()

        // Reopening a day that was already confirmed earlier (a different session, or just
        // scrolling back) should show "planned" from the start, not offer to confirm again.
        if case .weekPlan(let date) = context {
            let key = Calendar.current.startOfDay(for: date)
            self.isConfirmedForPlan = confirmedMealStore.loadConfirmedMeals()
                .first(where: { $0.id == key })?.recipe.id == recipe.id
        }

        pantryChangeCancellable = pantryStore.changes
            .sink { [weak self] in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.pantry = self.pantryStore.load()
                }
            }
    }

    /// Whether "Mark as Cooked" — the real pantry deduction — is honest to offer right now.
    /// Only once the day has arrived: cooking a day that hasn't happened yet isn't something
    /// the cook could actually have done. Same rule for a Week Plan preview and an
    /// already-confirmed meal — the only thing that differs between them is whether there's
    /// still a "confirm" action to offer.
    var canMarkAsCooked: Bool {
        switch context {
        case .weekPlan(let date), .confirmed(let date):
            return Calendar.current.startOfDay(for: date) <= Calendar.current.startOfDay(for: now)
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

    /// Records that the cook wants to eat this recipe on its planned day. Only meaningful for
    /// `.weekPlan` — never deducts from the pantry; that only happens when the day arrives and
    /// the cook actually marks it cooked (see `canMarkAsCooked`).
    func confirmPlannedMeal() {
        guard case .weekPlan(let date) = context else { return }
        confirmPlannedMealUseCase.execute(recipe: recipe, date: date, now: now)
        isConfirmedForPlan = true
        let weekday = date.formatted(.dateTime.weekday(.wide))
        notice = Notice(
            title: "Planned",
            message: "\(recipe.title) is planned for \(weekday). Nothing has been taken from your pantry yet.",
            dismissPops: false
        )
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
