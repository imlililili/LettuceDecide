import Foundation
import Testing
@testable import LettuceDecide

struct AddPantryIngredientUseCaseTests {
    private func makeUseCase(_ initial: [PantryIngredient] = []) -> (AddPantryIngredientUseCase, InMemoryPantryStore) {
        let store = InMemoryPantryStore(initial: initial)
        return (AddPantryIngredientUseCase(store: store), store)
    }

    private let today = Date(timeIntervalSince1970: 1_700_000_000)
    private var inThreeDays: Date { Calendar.current.date(byAdding: .day, value: 3, to: today)! }
    private var yesterday: Date { Calendar.current.date(byAdding: .day, value: -1, to: today)! }

    @Test func addPantryIngredient_succeeds_withValidQuantityAndFutureExpiry() throws {
        let (useCase, store) = makeUseCase()

        let pantry = try useCase.execute(
            name: "Milk",
            quantity: 1000,
            unit: .millilitres,
            storageLocation: .fridge,
            expiryDate: inThreeDays,
            now: today
        )

        #expect(pantry.count == 1)
        #expect(pantry.first?.ingredientName == "Milk")
        #expect(pantry.first?.quantity == 1000)
        #expect(store.load().count == 1)
    }

    @Test func addPantryIngredient_fails_whenQuantityIsZeroOrNegative() {
        let (useCase, _) = makeUseCase()

        #expect(throws: PantryIngredientError.invalidQuantity(provided: 0)) {
            try useCase.execute(name: "Rice", quantity: 0, unit: .grams, storageLocation: .pantry, now: today)
        }
        #expect(throws: PantryIngredientError.invalidQuantity(provided: -5)) {
            try useCase.execute(name: "Rice", quantity: -5, unit: .grams, storageLocation: .pantry, now: today)
        }
    }

    @Test func addPantryIngredient_fails_whenExpiryDateHasAlreadyPassed() {
        let (useCase, _) = makeUseCase()

        #expect(throws: PantryIngredientError.expiryDateAlreadyPassed(date: yesterday)) {
            try useCase.execute(
                name: "Yoghurt",
                quantity: 200,
                unit: .grams,
                storageLocation: .fridge,
                expiryDate: yesterday,
                now: today
            )
        }
    }

    @Test func addPantryIngredient_mergesQuantity_whenSameIngredientAndLocationAlreadyExists() throws {
        let existing = PantryIngredient(
            ingredientName: "eggs",
            quantity: 6,
            unit: .pieces,
            storageLocation: .fridge,
            expiryDate: Calendar.current.date(byAdding: .day, value: 10, to: today)
        )
        let (useCase, store) = makeUseCase([existing])

        let pantry = try useCase.execute(
            name: "Egg",
            quantity: 4,
            unit: .pieces,
            storageLocation: .fridge,
            expiryDate: inThreeDays,
            now: today
        )

        #expect(pantry.count == 1)
        #expect(pantry.first?.quantity == 10)
        // The more urgent expiry date wins the merge.
        #expect(pantry.first?.expiryDate == inThreeDays)
        #expect(pantry.first?.id == existing.id)
        #expect(store.load().first?.quantity == 10)
    }

    @Test func addPantryIngredient_keepsSeparateLines_whenLocationDiffers() throws {
        let (useCase, _) = makeUseCase([
            PantryIngredient(ingredientName: "peas", quantity: 100, unit: .grams, storageLocation: .freezer)
        ])

        let pantry = try useCase.execute(name: "peas", quantity: 100, unit: .grams, storageLocation: .fridge, now: today)

        #expect(pantry.count == 2)
    }
}
