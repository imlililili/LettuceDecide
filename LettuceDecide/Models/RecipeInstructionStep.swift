import Foundation

/// One numbered step of a recipe's method.
///
/// Real-world meaning: a single instruction the cook follows, in order. Rendered in-app as
/// the primary reading experience for a recipe (Spoonacular's terms require attribution to
/// the original source to be present on screen, not that the user be sent off to it).
struct RecipeInstructionStep: Identifiable, Codable, Equatable, Hashable {
    /// 1-based position in the method.
    let id: Int
    let stepText: String
    /// Names of the ingredients this step uses, as Spoonacular tags them — used to
    /// highlight which pantry items a step draws on.
    let ingredientNames: [String]

    init(id: Int, stepText: String, ingredientNames: [String] = []) {
        self.id = id
        self.stepText = stepText
        self.ingredientNames = ingredientNames
    }
}
