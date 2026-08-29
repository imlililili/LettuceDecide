import Foundation

/// A single recipe recommendation shown to the user.
struct Recipe: Identifiable, Codable, Equatable, Hashable {
    let id: Int
    let title: String
    let imageURL: URL?
    let readyInMinutes: Int?
    let servings: Int?
    let sourceURL: URL?
    /// HTML summary as returned by Spoonacular; render with an HTML-stripping helper before display.
    let summary: String?
    let healthScore: Double?
    let diets: [String]

    init(
        id: Int,
        title: String,
        imageURL: URL? = nil,
        readyInMinutes: Int? = nil,
        servings: Int? = nil,
        sourceURL: URL? = nil,
        summary: String? = nil,
        healthScore: Double? = nil,
        diets: [String] = []
    ) {
        self.id = id
        self.title = title
        self.imageURL = imageURL
        self.readyInMinutes = readyInMinutes
        self.servings = servings
        self.sourceURL = sourceURL
        self.summary = summary
        self.healthScore = healthScore
        self.diets = diets
    }
}

extension Recipe {
    /// A plain-text rendering of `summary` with HTML tags removed, for simple label display.
    var plainSummary: String? {
        guard let summary else { return nil }
        return summary.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
    }
}
