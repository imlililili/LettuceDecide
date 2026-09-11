import Foundation
import Testing
@testable import LettuceDecide

struct GenerateWeeklyMealPlanUseCaseTests {
    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private let monday = Date(timeIntervalSince1970: 1_699_833_600)

    private func week(_ count: Int, _ level: BusynessLevel = .relaxed) -> [ScheduleEntry] {
        (0..<count).map {
            ScheduleEntry(
                date: monday.addingTimeInterval(Double($0) * 86_400),
                busyness: level,
                calendar: utc
            )
        }
    }

    private func candidate(_ id: Int, allergens: Set<DietaryRestriction>? = []) -> PantryRecipeCandidate {
        PantryRecipeCandidate(
            recipe: Recipe(id: id, title: "Recipe \(id)", readyInMinutes: 30, containsAllergens: allergens),
            usedIngredientNames: ["onion"],
            missedIngredients: []
        )
    }

    private func makeUseCase(
        pantry: [PantryIngredient] = [
            PantryIngredient(ingredientName: "onion", quantity: 3, unit: .pieces, storageLocation: .pantry)
        ],
        candidates: [PantryRecipeCandidate] = (1...7).map { PantryRecipeCandidate(
            recipe: Recipe(id: $0, title: "Recipe \($0)", readyInMinutes: 30),
            usedIngredientNames: ["onion"],
            missedIngredients: []
        ) },
        preferences: UserPreferences = .default,
        repositoryError: Error? = nil
    ) -> (GenerateWeeklyMealPlanUseCase, InMemoryPantryStore) {
        let pantryStore = InMemoryPantryStore(initial: pantry)
        let useCase = GenerateWeeklyMealPlanUseCase(
            recipeRepository: MockRecipeRepository(candidates: candidates, errorToThrow: repositoryError),
            pantryStore: pantryStore,
            preferencesStore: InMemoryUserPreferencesStore(initial: preferences)
        )
        return (useCase, pantryStore)
    }

    @Test func generatesASevenDayPlan() async throws {
        let (useCase, _) = makeUseCase()

        let plan = try await useCase.execute(week: week(7), now: monday)

        #expect(plan.days.count == 7)
        #expect(plan.days.allSatisfy { $0.assignedRecipe != nil })
        #expect(!plan.isFromCache)
    }

    @Test func marksThePlanAsFromCache_whenTheCandidatePoolIs() async throws {
        let cachedCandidates: [PantryRecipeCandidate] = (1...7).map {
            var c = PantryRecipeCandidate(
                recipe: Recipe(id: $0, title: "Recipe \($0)", readyInMinutes: 30),
                usedIngredientNames: ["onion"],
                missedIngredients: []
            )
            c.isFromCache = true
            return c
        }
        let (useCase, _) = makeUseCase(candidates: cachedCandidates)

        let plan = try await useCase.execute(week: week(7), now: monday)

        #expect(plan.isFromCache)
    }

    @Test func fails_whenThePantryIsEmpty() async {
        let (useCase, _) = makeUseCase(pantry: [])

        await #expect(throws: WeeklyMealPlanError.self) {
            try await useCase.execute(week: week(7), now: monday)
        }
    }

    @Test func fails_whenFewerThanSevenDaysAreProvided() async {
        let (useCase, _) = makeUseCase()

        do {
            _ = try await useCase.execute(week: week(6), now: monday)
            Issue.record("expected incompleteWeek")
        } catch let WeeklyMealPlanError.incompleteWeek(daysProvided) {
            #expect(daysProvided == 6)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test func fails_whenTheRecipeServiceIsUnavailable() async {
        struct Boom: Error {}
        let (useCase, _) = makeUseCase(repositoryError: Boom())

        do {
            _ = try await useCase.execute(week: week(7), now: monday)
            Issue.record("expected recommendationServiceUnavailable")
        } catch WeeklyMealPlanError.recommendationServiceUnavailable {
            // expected
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test func leavesTheRealPantryUntouched() async throws {
        let (useCase, store) = makeUseCase(
            pantry: [
                PantryIngredient(ingredientName: "chickpeas", quantity: 400, unit: .grams, storageLocation: .pantry)
            ],
            candidates: [
                PantryRecipeCandidate(
                    recipe: Recipe(
                        id: 1,
                        title: "Chickpea stew",
                        readyInMinutes: 30,
                        requiredIngredients: [RecipeIngredient(id: 1, name: "chickpeas", requiredQuantity: 400, unit: .grams)]
                    ),
                    usedIngredientNames: ["chickpeas"],
                    missedIngredients: []
                )
            ]
        )
        let before = store.load()

        _ = try await useCase.execute(week: week(7), now: monday)

        #expect(store.load() == before)
        #expect(store.load().first?.quantity == 400)
    }

    @Test func excludesRecipesThatAreUnsafeForTheCooksRestrictions() async throws {
        var preferences = UserPreferences.default
        preferences.intolerances = [.dairy]
        let (useCase, _) = makeUseCase(
            candidates: [
                candidate(1, allergens: [.dairy]),   // unsafe
                candidate(2, allergens: []),          // safe
            ],
            preferences: preferences
        )

        let plan = try await useCase.execute(week: week(7), now: monday)

        let assignedIDs = Set(plan.days.compactMap { $0.assignedRecipe?.id })
        #expect(!assignedIDs.contains(1))
        #expect(assignedIDs == [2])
    }

    /// Regression for the Decide-tab removal: once `RecommendMealsFromPantryUseCase` is gone,
    /// this use case is the *only* remaining gate on both the allergen/diet safety rule and
    /// each day's `BusynessLevel` cap — nothing else re-checks them. A deliberately
    /// adversarial pool (a recipe that's fast but unsafe, one that's safe but too slow for
    /// `.busy`, and enough genuinely-safe-and-fast fillers) proves every assigned day still
    /// respects both rules, across a mixed-busyness week.
    @Test func everyAssignedDayRespectsSafetyAndThatDaysBusynessCap() async throws {
        var preferences = UserPreferences.default
        preferences.intolerances = [.dairy]

        func fixture(_ id: Int, minutes: Int, allergens: Set<DietaryRestriction>? = []) -> PantryRecipeCandidate {
            PantryRecipeCandidate(
                recipe: Recipe(id: id, title: "Recipe \(id)", readyInMinutes: minutes, containsAllergens: allergens),
                usedIngredientNames: ["onion"],
                missedIngredients: []
            )
        }

        // Would fill any .busy day if the safety rule were skipped.
        let unsafeButQuick = fixture(101, minutes: 10, allergens: [.dairy])
        // Safe, but only .relaxed is loose enough for it.
        let safeButSlow = fixture(102, minutes: 60)
        // Safe and quick enough to fit even .busy.
        let safeQuickFillers = (1...5).map { fixture($0, minutes: 15) }
        // Safe, fits .normal/.relaxed but not .busy.
        let safeMediumFillers = (6...10).map { fixture($0, minutes: 35) }

        let (useCase, _) = makeUseCase(
            candidates: [unsafeButQuick, safeButSlow] + safeQuickFillers + safeMediumFillers,
            preferences: preferences
        )
        let mixedBusyness = zip([BusynessLevel.busy, .normal, .relaxed, .busy, .normal, .relaxed, .busy], 0..<7).map {
            level, offset in
            ScheduleEntry(date: monday.addingTimeInterval(Double(offset) * 86_400), busyness: level, calendar: utc)
        }

        let plan = try await useCase.execute(week: mixedBusyness, now: monday)

        #expect(plan.days.contains { $0.assignedRecipe != nil }) // sanity: the pool isn't degenerate
        for day in plan.days {
            guard let recipe = day.assignedRecipe else { continue }
            #expect(recipe.isSafe(for: preferences.intolerances), "day \(day.date) was assigned an unsafe recipe")
            #expect(day.busyness.permits(recipe), "day \(day.date) was assigned a recipe over its busyness cap")
            #expect(recipe.id != 101, "the unsafe recipe must never be picked, however well it fits a busy day")
        }
    }
}
