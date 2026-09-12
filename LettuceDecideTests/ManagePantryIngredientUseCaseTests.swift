import Foundation
import Testing
@testable import LettuceDecide

struct ManagePantryIngredientUseCaseTests {
    private func makeUseCase(_ initial: [PantryIngredient] = []) -> (ManagePantryIngredientUseCase, InMemoryPantryStore) {
        let store = InMemoryPantryStore(initial: initial)
        return (ManagePantryIngredientUseCase(store: store), store)
    }

    private let today = Date(timeIntervalSince1970: 1_700_000_000)
    private var inThreeDays: Date { Calendar.current.date(byAdding: .day, value: 3, to: today)! }
    private var yesterday: Date { Calendar.current.date(byAdding: .day, value: -1, to: today)! }

    // MARK: - add

    @Test func add_succeeds_withValidQuantityAndFutureExpiry() throws {
        let (useCase, store) = makeUseCase()

        let pantry = try useCase.execute(
            .add(name: "Milk", quantity: 1000, unit: .millilitres, storageLocation: .fridge, expiryDate: inThreeDays),
            now: today
        )

        #expect(pantry.map(\.ingredientName) == ["Milk"])
        #expect(pantry.first?.quantity == 1000)
        #expect(store.load().count == 1)
    }

    @Test func add_fails_whenQuantityIsZeroOrNegative() {
        let (useCase, _) = makeUseCase()

        #expect(throws: PantryIngredientError.invalidQuantity(provided: 0)) {
            try useCase.execute(.add(name: "Rice", quantity: 0, unit: .grams, storageLocation: .pantry, expiryDate: nil), now: today)
        }
        #expect(throws: PantryIngredientError.invalidQuantity(provided: -5)) {
            try useCase.execute(.add(name: "Rice", quantity: -5, unit: .grams, storageLocation: .pantry, expiryDate: nil), now: today)
        }
    }

    @Test func add_fails_whenExpiryDateHasAlreadyPassed() {
        let (useCase, _) = makeUseCase()

        #expect(throws: PantryIngredientError.expiryDateAlreadyPassed(date: yesterday)) {
            try useCase.execute(
                .add(name: "Yoghurt", quantity: 200, unit: .grams, storageLocation: .fridge, expiryDate: yesterday),
                now: today
            )
        }
    }

    @Test func add_mergesQuantityAndKeepsEarlierExpiry_whenALineWithTheSameIdentityExists() throws {
        let existing = PantryIngredient(
            ingredientName: "eggs",
            quantity: 6,
            unit: .pieces,
            storageLocation: .fridge,
            expiryDate: Calendar.current.date(byAdding: .day, value: 10, to: today)
        )
        let (useCase, store) = makeUseCase([existing])

        let pantry = try useCase.execute(
            .add(name: "Egg", quantity: 4, unit: .pieces, storageLocation: .fridge, expiryDate: inThreeDays),
            now: today
        )

        #expect(pantry.count == 1)
        #expect(pantry.first?.quantity == 10)
        #expect(pantry.first?.expiryDate == inThreeDays)
        #expect(pantry.first?.id == existing.id)
        #expect(store.load().first?.quantity == 10)
    }

    @Test func add_keepsSeparateLines_whenLocationDiffers() throws {
        let (useCase, _) = makeUseCase([
            PantryIngredient(ingredientName: "peas", quantity: 100, unit: .grams, storageLocation: .freezer)
        ])

        let pantry = try useCase.execute(
            .add(name: "peas", quantity: 100, unit: .grams, storageLocation: .fridge, expiryDate: nil),
            now: today
        )

        #expect(pantry.count == 2)
    }

    // MARK: - Volume normalisation

    @Test func add_normalisesAVolumeUnitToMillilitresEvenWithNoExistingLine() throws {
        let (useCase, store) = makeUseCase()

        let pantry = try useCase.execute(
            .add(name: "olive oil", quantity: 2, unit: .cups, storageLocation: .pantry, expiryDate: nil),
            now: today
        )

        // 2 cups -> 480ml, converted unconditionally, not only when it collides with an
        // existing line.
        #expect(pantry.first?.unit == .millilitres)
        #expect(pantry.first?.quantity == 480)
        #expect(store.load().first?.unit == .millilitres)
    }

    @Test func add_normalisesAndMergesOntoAnExistingMillilitresLine() throws {
        let existing = PantryIngredient(
            ingredientName: "olive oil", quantity: 100, unit: .millilitres, storageLocation: .pantry
        )
        let (useCase, _) = makeUseCase([existing])

        let pantry = try useCase.execute(
            .add(name: "olive oil", quantity: 1, unit: .cups, storageLocation: .pantry, expiryDate: nil),
            now: today
        )

        #expect(pantry.count == 1)
        #expect(pantry.first?.quantity == 340) // 100ml already there + 240ml (1 cup)
    }

    @Test func add_neverMergesAVolumeLineWithAGramsOrPiecesLineForTheSameIngredient() throws {
        let existing = PantryIngredient(
            ingredientName: "onion", quantity: 500, unit: .grams, storageLocation: .fridge
        )
        let (useCase, _) = makeUseCase([existing])

        let pantry = try useCase.execute(
            .add(name: "onion", quantity: 1, unit: .cups, storageLocation: .fridge, expiryDate: nil),
            now: today
        )

        #expect(pantry.count == 2) // never guesses a cup <-> gram conversion
        #expect(Set(pantry.map(\.unit)) == [.grams, .millilitres])
    }

    @Test func update_normalisesAVolumeUnitToMillilitres() throws {
        let line = PantryIngredient(ingredientName: "milk", quantity: 200, unit: .millilitres, storageLocation: .fridge)
        let (useCase, store) = makeUseCase([line])

        let pantry = try useCase.execute(
            .update(id: line.id, quantity: 1, unit: .cups, storageLocation: .fridge, expiryDate: nil),
            now: today
        )

        #expect(pantry.first?.unit == .millilitres)
        #expect(pantry.first?.quantity == 240)
        #expect(store.load().first?.unit == .millilitres)
    }

    @Test func add_recordsTheIngredientIdWhenSupplied() throws {
        let (useCase, _) = makeUseCase()

        let pantry = try useCase.execute(
            .add(name: "olive oil", quantity: 500, unit: .millilitres, storageLocation: .pantry, expiryDate: nil, ingredientId: 4053),
            now: today
        )

        #expect(pantry.first?.ingredientId == 4053)
    }

    @Test func add_mergesByIdEvenWhenNamesDiffer() throws {
        let existing = PantryIngredient(
            ingredientName: "spring onion", quantity: 2, unit: .pieces, storageLocation: .fridge, ingredientId: 11291
        )
        let (useCase, _) = makeUseCase([existing])

        let pantry = try useCase.execute(
            .add(name: "green onions", quantity: 3, unit: .pieces, storageLocation: .fridge, expiryDate: nil, ingredientId: 11291),
            now: today
        )

        #expect(pantry.count == 1)
        #expect(pantry.first?.quantity == 5)
    }

    // MARK: - update

    @Test func update_changesTheLineInPlace() throws {
        let line = PantryIngredient(ingredientName: "Butter", quantity: 250, unit: .grams, storageLocation: .fridge)
        let (useCase, store) = makeUseCase([line])

        let pantry = try useCase.execute(
            .update(id: line.id, quantity: 100, unit: .grams, storageLocation: .fridge, expiryDate: nil),
            now: today
        )

        #expect(pantry.first?.quantity == 100)
        #expect(store.load().first?.quantity == 100)
    }

    @Test func update_appliesTheSameValidationAsAdd() {
        let line = PantryIngredient(ingredientName: "Butter", quantity: 250, unit: .grams, storageLocation: .fridge)
        let (useCase, _) = makeUseCase([line])

        #expect(throws: PantryIngredientError.invalidQuantity(provided: 0)) {
            try useCase.execute(.update(id: line.id, quantity: 0, unit: .grams, storageLocation: .fridge, expiryDate: nil), now: today)
        }
    }

    @Test func update_fails_whenTheLineIsAlreadyGone() {
        let (useCase, _) = makeUseCase()
        let ghost = UUID()

        #expect(throws: PantryIngredientError.ingredientNoLongerInPantry(id: ghost)) {
            try useCase.execute(.update(id: ghost, quantity: 5, unit: .pieces, storageLocation: .pantry, expiryDate: nil), now: today)
        }
    }

    // MARK: - remove

    @Test func remove_deletesTheLine() throws {
        let line = PantryIngredient(ingredientName: "Bread", quantity: 1, unit: .pieces, storageLocation: .pantry)
        let (useCase, store) = makeUseCase([line])

        let pantry = try useCase.execute(.remove(id: line.id))

        #expect(pantry.isEmpty)
        #expect(store.load().isEmpty)
    }

    @Test func remove_isASilentNoOp_whenTheLineIsAlreadyGone() throws {
        let line = PantryIngredient(ingredientName: "Bread", quantity: 1, unit: .pieces, storageLocation: .pantry)
        let (useCase, _) = makeUseCase([line])

        let pantry = try useCase.execute(.remove(id: UUID()))

        #expect(pantry.map(\.ingredientName) == ["Bread"])
    }
}
