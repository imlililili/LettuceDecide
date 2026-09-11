import Foundation
import Testing
@testable import LettuceDecide

struct WeeklyPlanBuilderTests {
    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    /// 2023-11-13T00:00:00Z, a Monday.
    private let monday = Date(timeIntervalSince1970: 1_699_833_600)
    private let now = Date(timeIntervalSince1970: 1_699_833_600)

    // MARK: - Fixtures

    private func recipe(_ id: Int, minutes: Int = 30, ingredients: [RecipeIngredient] = []) -> Recipe {
        Recipe(id: id, title: "Recipe \(id)", readyInMinutes: minutes, requiredIngredients: ingredients)
    }

    private func ingredient(_ id: Int, _ name: String, _ qty: Double, _ unit: IngredientUnit) -> RecipeIngredient {
        RecipeIngredient(id: id, name: name, requiredQuantity: qty, unit: unit)
    }

    private func candidate(
        _ recipe: Recipe,
        used: [String] = [],
        missed: [RecipeIngredient] = []
    ) -> PantryRecipeCandidate {
        PantryRecipeCandidate(recipe: recipe, usedIngredientNames: used, missedIngredients: missed)
    }

    private func week(_ levels: [BusynessLevel]) -> [ScheduleEntry] {
        levels.enumerated().map { offset, level in
            ScheduleEntry(
                date: monday.addingTimeInterval(Double(offset) * 86_400),
                busyness: level,
                calendar: utc
            )
        }
    }

    private var sevenRelaxedDays: [ScheduleEntry] { week(Array(repeating: .relaxed, count: 7)) }

    // MARK: - Assignment

    @Test func assignsEveryDayWhenTheCandidatePoolIsBigEnough() {
        let candidates = (1...7).map { candidate(recipe($0)) }

        let plan = WeeklyPlanBuilder.build(
            candidates: candidates,
            busyness: sevenRelaxedDays,
            startingFrom: [],
            now: now
        )

        #expect(plan.days.count == 7)
        #expect(plan.days.allSatisfy { $0.assignedRecipe != nil })
        let ids = plan.days.compactMap { $0.assignedRecipe?.id }
        #expect(Set(ids).count == 7)
    }

    /// Regression for a real bug: with only a handful of candidates, most of which carry a
    /// slow (or Spoonacular's generic ~45-minute placeholder) `readyInMinutes`, four `.normal`
    /// days in a row came back "no match" even though .normal's cap (≤40 min) is meant to be
    /// easy to satisfy. The fix was widening the upstream candidate pool, not the builder — so
    /// this proves the *assignment* logic itself has no bug once the pool is healthy: given a
    /// realistic-sized pool (18 candidates, mostly slow, a real minority fast) it fills every
    /// day of the exact busyness pattern that failed live (relaxed/busy/normal×4/relaxed).
    @Test func fillsAllSevenDaysWhenTheCandidatePoolIsRealisticallySized() {
        // Mirrors what a live Spoonacular response actually looks like: most results carry no
        // real timing data and land on a slow/placeholder duration; only a minority are fast.
        let slowFiller = (1...10).map { candidate(recipe($0, minutes: 45)) }
        let normalEligible = (11...14).map { candidate(recipe($0, minutes: 35)) }
        let busyEligible = (15...16).map {
            candidate(recipe($0, minutes: 15, ingredients: (0..<3).map { i in ingredient(i, "ing \(i)", 1, .pieces) }))
        }
        let moreFiller = (17...18).map { candidate(recipe($0, minutes: 45)) }
        let pool = slowFiller + normalEligible + busyEligible + moreFiller
        #expect(pool.count == 18)

        let busyness = week([.relaxed, .busy, .normal, .normal, .relaxed, .normal, .normal])

        let plan = WeeklyPlanBuilder.build(candidates: pool, busyness: busyness, startingFrom: [], now: now)

        #expect(plan.days.allSatisfy { $0.assignedRecipe != nil })
        let assignedIDs = plan.days.compactMap { $0.assignedRecipe?.id }
        #expect(Set(assignedIDs).count == 7) // no repeats either
    }

    @Test func daysAreOrderedMondayToSunday() {
        let plan = WeeklyPlanBuilder.build(
            candidates: (1...7).map { candidate(recipe($0)) },
            busyness: Array(sevenRelaxedDays.reversed()),
            startingFrom: [],
            now: now
        )

        #expect(plan.days.map(\.date) == plan.days.map(\.date).sorted())
    }

    @Test func marksLaterDaysNoMatchWhenThePoolRunsOut() {
        let candidates = (1...3).map { candidate(recipe($0)) }

        let plan = WeeklyPlanBuilder.build(
            candidates: candidates,
            busyness: sevenRelaxedDays,
            startingFrom: [],
            now: now
        )

        let assigned = plan.days.prefix(3)
        let unmatched = plan.days.suffix(4)
        #expect(assigned.allSatisfy { $0.assignedRecipe != nil })
        #expect(unmatched.allSatisfy { $0.assignedRecipe == nil })
    }

    @Test func neverAssignsTheSameRecipeToTwoDays() {
        let candidates = [candidate(recipe(1)), candidate(recipe(2))]

        let plan = WeeklyPlanBuilder.build(
            candidates: candidates,
            busyness: sevenRelaxedDays,
            startingFrom: [],
            now: now
        )

        let assignedIDs = plan.days.compactMap { $0.assignedRecipe?.id }
        #expect(assignedIDs.count == 2)
        #expect(Set(assignedIDs).count == 2)
    }

    // MARK: - Busyness constraint

    @Test func aBusyDaySkipsRecipesOverTheTimeCap() {
        let quick = candidate(recipe(1, minutes: 15))
        let slow = candidate(recipe(2, minutes: 45))

        let plan = WeeklyPlanBuilder.build(
            candidates: [slow, quick],
            busyness: week([.busy]),
            startingFrom: [],
            now: now
        )

        #expect(plan.days.first?.assignedRecipe?.id == 1)
    }

    @Test func aBusyDayWithOnlySlowCandidatesIsNoMatch() {
        let plan = WeeklyPlanBuilder.build(
            candidates: [candidate(recipe(1, minutes: 45))],
            busyness: week([.busy]),
            startingFrom: [],
            now: now
        )

        #expect(plan.days.first?.assignedRecipe == nil)
    }

    @Test func aBusyDayRespectsTheIngredientCountCap() {
        let lean = candidate(recipe(1, minutes: 15, ingredients: (0..<3).map {
            ingredient($0, "ing \($0)", 1, .pieces)
        }))
        let crowded = candidate(recipe(2, minutes: 15, ingredients: (0..<6).map {
            ingredient($0, "ing \($0)", 1, .pieces)
        }))

        let plan = WeeklyPlanBuilder.build(
            candidates: [crowded, lean],
            busyness: week([.busy]),
            startingFrom: [],
            now: now
        )

        #expect(plan.days.first?.assignedRecipe?.id == 1)
    }

    // MARK: - Virtual pantry deduction

    @Test func doesNotMutateThePantryItIsHanded() {
        let pantry = [
            PantryIngredient(ingredientName: "chickpeas", quantity: 400, unit: .grams, storageLocation: .pantry)
        ]
        let recipeNeedingAll = recipe(1, ingredients: [ingredient(1, "chickpeas", 400, .grams)])

        _ = WeeklyPlanBuilder.build(
            candidates: [candidate(recipeNeedingAll, used: ["chickpeas"])],
            busyness: week([.relaxed]),
            startingFrom: pantry,
            now: now
        )

        #expect(pantry.count == 1)
        #expect(pantry.first?.quantity == 400)
    }

    @Test func drainsSharedStockAcrossTheWeekAndBuysTheShortfall() {
        let pantry = [
            PantryIngredient(ingredientName: "chickpeas", quantity: 400, unit: .grams, storageLocation: .pantry)
        ]
        let a = recipe(1, ingredients: [ingredient(1, "chickpeas", 300, .grams)])
        let b = recipe(2, ingredients: [ingredient(1, "chickpeas", 300, .grams)])

        let plan = WeeklyPlanBuilder.build(
            candidates: [candidate(a, used: ["chickpeas"]), candidate(b, used: ["chickpeas"])],
            busyness: week([.relaxed, .relaxed]),
            startingFrom: pantry,
            now: now
        )

        // Day 1 uses 300 of 400. Day 2 needs 300, only 100 left → buy 200.
        let chickpeas = plan.shoppingList.first { $0.ingredientName.normalizedIngredientName == "chickpea" }
        #expect(chickpeas?.requiredQuantity == 200)
        #expect(chickpeas?.unit == .grams)
    }

    @Test func aFullyMissingIngredientIsBoughtInFull() {
        let plan = WeeklyPlanBuilder.build(
            candidates: [candidate(recipe(1, ingredients: [ingredient(15076, "salmon", 2, .pieces)]))],
            busyness: week([.relaxed]),
            startingFrom: [
                PantryIngredient(ingredientName: "onion", quantity: 3, unit: .pieces, storageLocation: .pantry)
            ],
            now: now
        )

        #expect(plan.shoppingList.count == 1)
        #expect(plan.shoppingList.first?.ingredientName == "salmon")
        #expect(plan.shoppingList.first?.requiredQuantity == 2)
    }

    @Test func anIngredientHeldInADifferentUnitIsLeftOffTheList() {
        let plan = WeeklyPlanBuilder.build(
            candidates: [candidate(recipe(1, ingredients: [ingredient(20081, "flour", 300, .grams)]))],
            busyness: week([.relaxed]),
            startingFrom: [
                PantryIngredient(ingredientName: "flour", quantity: 2, unit: .cups, storageLocation: .pantry)
            ],
            now: now
        )

        #expect(plan.shoppingList.isEmpty)
    }

    // MARK: - Shopping list dedupe

    @Test func mergesMissingIngredientsWithTheSameNameAndUnit() {
        let a = recipe(1, ingredients: [ingredient(1022047, "curry powder", 1, .tablespoons)])
        let b = recipe(2, ingredients: [ingredient(1022047, "curry powder", 2, .tablespoons)])

        let plan = WeeklyPlanBuilder.build(
            candidates: [candidate(a), candidate(b)],
            busyness: week([.relaxed, .relaxed]),
            startingFrom: [],
            now: now
        )

        #expect(plan.shoppingList.count == 1)
        #expect(plan.shoppingList.first?.ingredientName == "curry powder")
        #expect(plan.shoppingList.first?.requiredQuantity == 3)
    }

    @Test func keepsTheSameIngredientInDifferentUnitsAsSeparateLines() {
        let a = recipe(1, ingredients: [ingredient(20081, "flour", 200, .grams)])
        let b = recipe(2, ingredients: [ingredient(20081, "flour", 2, .cups)])

        let plan = WeeklyPlanBuilder.build(
            candidates: [candidate(a), candidate(b)],
            busyness: week([.relaxed, .relaxed]),
            startingFrom: [],
            now: now
        )

        #expect(plan.shoppingList.count == 2)
        #expect(Set(plan.shoppingList.map(\.unit)) == [.grams, .cups])
    }
}
