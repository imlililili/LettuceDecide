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
}
