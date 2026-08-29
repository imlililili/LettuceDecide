import Foundation

/// Mirrors Spoonacular's supported `diet` values.
/// https://spoonacular.com/food-api/docs#Diets
enum DietPreference: String, CaseIterable, Identifiable, Codable {
    case none
    case glutenFree = "Gluten Free"
    case ketogenic = "Ketogenic"
    case vegetarian = "Vegetarian"
    case lactoVegetarian = "Lacto-Vegetarian"
    case ovoVegetarian = "Ovo-Vegetarian"
    case vegan = "Vegan"
    case pescetarian = "Pescetarian"
    case paleo = "Paleo"
    case primal = "Primal"
    case lowFodmap = "Low FODMAP"
    case whole30 = "Whole30"

    var id: String { rawValue }

    /// Value to send in the Spoonacular `diet` query parameter, nil when no filter applies.
    var apiValue: String? { self == .none ? nil : rawValue }

    var displayName: String { self == .none ? "No preference" : rawValue }
}
