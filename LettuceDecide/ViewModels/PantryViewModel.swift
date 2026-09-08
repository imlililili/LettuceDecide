import Foundation
import Combine

/// The editable form state behind the Add / Edit Ingredient sheet. Maps onto a
/// `ManagePantryIngredientUseCase.Action`.
struct IngredientDraft: Equatable {
    var name: String = ""
    var quantity: Double = 1
    var unit: IngredientUnit = .grams
    var storageLocation: StorageLocation = .fridge
    var includesExpiryDate: Bool = false
    var expiryDate: Date = Date()

    var expiryDateOrNil: Date? { includesExpiryDate ? expiryDate : nil }

    init() {}

    init(from ingredient: PantryIngredient) {
        name = ingredient.ingredientName
        quantity = ingredient.quantity
        unit = ingredient.unit
        storageLocation = ingredient.storageLocation
        includesExpiryDate = ingredient.expiryDate != nil
        expiryDate = ingredient.expiryDate ?? Date()
    }
}

/// One storage location's worth of pantry lines, for the grouped Pantry list.
struct PantrySection: Identifiable {
    var id: StorageLocation { location }
    let location: StorageLocation
    let ingredients: [PantryIngredient]
}

@MainActor
final class PantryViewModel: ObservableObject {
    @Published private(set) var ingredients: [PantryIngredient] = []

    private let store: PantryStoring
    private let managePantry: ManagePantryIngredientUseCase

    init(store: PantryStoring) {
        self.store = store
        self.managePantry = ManagePantryIngredientUseCase(store: store)
        reload()
    }

    var isEmpty: Bool { ingredients.isEmpty }

    /// Pantry lines grouped by location (most perishable first), each group sorted with the
    /// most urgent expiries at the top.
    var sections: [PantrySection] {
        Dictionary(grouping: ingredients, by: \.storageLocation)
            .map { location, items in
                PantrySection(location: location, ingredients: items.sorted(by: Self.mostUrgentFirst))
            }
            .sorted { $0.location.sortOrder < $1.location.sortOrder }
    }

    func reload() {
        ingredients = store.load()
    }

    /// Records a new ingredient (the use case merges duplicates and rejects invalid
    /// quantities / past expiry dates).
    func add(_ draft: IngredientDraft) throws {
        try managePantry.execute(.add(
            name: draft.name,
            quantity: draft.quantity,
            unit: draft.unit,
            storageLocation: draft.storageLocation,
            expiryDate: draft.expiryDateOrNil
        ))
        reload()
    }

    /// Edits an existing line in place. The ingredient's name is fixed once recorded — to
    /// change it, delete the line and add a new one.
    func update(_ ingredient: PantryIngredient, with draft: IngredientDraft) throws {
        try managePantry.execute(.update(
            id: ingredient.id,
            quantity: draft.quantity,
            unit: draft.unit,
            storageLocation: draft.storageLocation,
            expiryDate: draft.expiryDateOrNil
        ))
        reload()
    }

    func delete(_ ingredient: PantryIngredient) {
        try? managePantry.execute(.remove(id: ingredient.id))
        reload()
    }

    func delete(at offsets: IndexSet, in location: StorageLocation) {
        guard let section = sections.first(where: { $0.location == location }) else { return }
        for index in offsets {
            delete(section.ingredients[index])
        }
    }

    private static func mostUrgentFirst(_ lhs: PantryIngredient, _ rhs: PantryIngredient) -> Bool {
        switch (lhs.expiryDate, rhs.expiryDate) {
        case let (l?, r?): return l < r
        case (_?, nil): return true
        case (nil, _?): return false
        case (nil, nil): return lhs.ingredientName < rhs.ingredientName
        }
    }
}
