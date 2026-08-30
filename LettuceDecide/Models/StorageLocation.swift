import Foundation

/// Where a pantry ingredient physically lives.
///
/// Real-world meaning: the location a cook would walk to in order to find the ingredient.
/// It matters to the domain because it changes how quickly food needs to be used — a
/// half-used carton in the fridge is a "use it this week" problem in a way that the same
/// item in the freezer is not.
enum StorageLocation: String, CaseIterable, Identifiable, Codable {
    case fridge
    case freezer
    case pantry

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fridge: return "Fridge"
        case .freezer: return "Freezer"
        case .pantry: return "Pantry"
        }
    }

    /// Order the Pantry screen groups locations in — most perishable first.
    var sortOrder: Int {
        switch self {
        case .fridge: return 0
        case .freezer: return 1
        case .pantry: return 2
        }
    }
}
