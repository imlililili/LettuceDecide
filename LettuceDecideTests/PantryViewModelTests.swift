import Foundation
import Testing
@testable import LettuceDecide

@MainActor
struct PantryViewModelTests {
    private func draft(
        name: String,
        quantity: Double = 100,
        unit: IngredientUnit = .grams,
        location: StorageLocation = .fridge
    ) -> IngredientDraft {
        var d = IngredientDraft()
        d.name = name
        d.quantity = quantity
        d.unit = unit
        d.storageLocation = location
        return d
    }

    @Test func addRecordsAndReloadsTheIngredient() throws {
        let store = InMemoryPantryStore()
        let viewModel = PantryViewModel(store: store)

        try viewModel.add(draft(name: "Spinach"))

        #expect(viewModel.ingredients.map(\.ingredientName) == ["Spinach"])
        #expect(store.load().count == 1)
    }

    @Test func addSurfacesDomainValidationErrors() {
        let viewModel = PantryViewModel(store: InMemoryPantryStore())

        #expect(throws: PantryIngredientError.invalidQuantity(provided: 0)) {
            try viewModel.add(draft(name: "Rice", quantity: 0))
        }
    }

    @Test func sectionsAreGroupedByLocationMostPerishableFirst() throws {
        let viewModel = PantryViewModel(store: InMemoryPantryStore())
        try viewModel.add(draft(name: "Rice", location: .pantry))
        try viewModel.add(draft(name: "Peas", location: .freezer))
        try viewModel.add(draft(name: "Milk", location: .fridge))

        #expect(viewModel.sections.map(\.location) == [.fridge, .freezer, .pantry])
    }

    @Test func addMergesDuplicatePantryLines() throws {
        let viewModel = PantryViewModel(store: InMemoryPantryStore())
        try viewModel.add(draft(name: "eggs", quantity: 6, unit: .pieces))
        try viewModel.add(draft(name: "Egg", quantity: 4, unit: .pieces))

        #expect(viewModel.ingredients.count == 1)
        #expect(viewModel.ingredients.first?.quantity == 10)
    }

    @Test func updateChangesQuantityInPlace() throws {
        let store = InMemoryPantryStore()
        let viewModel = PantryViewModel(store: store)
        try viewModel.add(draft(name: "Butter", quantity: 250))
        let existing = try #require(viewModel.ingredients.first)

        var edited = IngredientDraft(from: existing)
        edited.quantity = 100
        try viewModel.update(existing, with: edited)

        #expect(viewModel.ingredients.first?.quantity == 100)
        #expect(store.load().first?.quantity == 100)
    }

    @Test func deleteRemovesTheLine() throws {
        let viewModel = PantryViewModel(store: InMemoryPantryStore())
        try viewModel.add(draft(name: "Bread"))
        let existing = try #require(viewModel.ingredients.first)

        viewModel.delete(existing)

        #expect(viewModel.ingredients.isEmpty)
    }
}
