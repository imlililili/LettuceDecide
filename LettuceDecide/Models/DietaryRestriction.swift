import Foundation

/// Mirrors Spoonacular's supported `intolerances` values so filters map 1:1 onto API requests.
/// https://spoonacular.com/food-api/docs#Intolerances
enum DietaryRestriction: String, CaseIterable, Identifiable, Codable {
    case dairy
    case egg
    case gluten
    case grain
    case peanut
    case seafood
    case sesame
    case shellfish
    case soy
    case sulfite
    case treeNut = "Tree Nut"
    case wheat

    var id: String { rawValue }

    /// Value to send in the Spoonacular `intolerances` query parameter.
    var apiValue: String { rawValue }

    var displayName: String {
        switch self {
        case .dairy: return "Dairy"
        case .egg: return "Egg"
        case .gluten: return "Gluten"
        case .grain: return "Grain"
        case .peanut: return "Peanut"
        case .seafood: return "Seafood"
        case .sesame: return "Sesame"
        case .shellfish: return "Shellfish"
        case .soy: return "Soy"
        case .sulfite: return "Sulfite"
        case .treeNut: return "Tree Nut"
        case .wheat: return "Wheat"
        }
    }

    var symbolName: String {
        switch self {
        case .dairy: return "drop.fill"
        case .egg: return "oval.fill"
        case .gluten, .grain, .wheat: return "leaf.fill"
        case .peanut, .treeNut: return "circle.hexagongrid.fill"
        case .seafood, .shellfish: return "fish.fill"
        case .sesame: return "circle.grid.2x2.fill"
        case .soy: return "circle.fill"
        case .sulfite: return "flask.fill"
        }
    }
}
