import Foundation
import Testing
@testable import LettuceDecide

/// The pantry inventory rules live in `ManagePantryIngredientUseCaseTests`. This covers only
/// what the view model adds: reloading its published list after a change, grouping for the
/// screen, and surfacing the use case's errors.
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

    @Test func reloadsThePublishedListAfterAddUpdateAndDelete() throws {
        let store = InMemoryPantryStore()
        let viewModel = PantryViewModel(store: store)

        try viewModel.add(draft(name: "Spinach"))
        #expect(viewModel.ingredients.map(\.ingredientName) == ["Spinach"])

        let line = try #require(viewModel.ingredients.first)
        var edited = IngredientDraft(from: line)
        edited.quantity = 50
        try viewModel.update(line, with: edited)
        #expect(viewModel.ingredients.first?.quantity == 50)

        viewModel.delete(line)
        #expect(viewModel.ingredients.isEmpty)
    }

    @Test func surfacesTheUseCasesValidationError() {
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
}
