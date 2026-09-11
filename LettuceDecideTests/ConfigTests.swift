import Foundation
import Testing
@testable import LettuceDecide

/// Regression coverage for a real incident: a Spoonacular API key with an accidental
/// whitespace/newline (e.g. from copying it out of a terminal) turned every recipe request
/// into a silent 401, which `GenerateWeeklyMealPlanUseCase` then reported as a generic
/// "couldn't reach the recipe service" — indistinguishable from an actual network outage.
struct ConfigTests {
    @Test func spoonacularAPIKeyTrimsWhitespaceAndNewlinesFromTheEnvironmentVariable() {
        setenv("SPOONACULAR_API_KEY", "abc123\n", 1)
        defer { unsetenv("SPOONACULAR_API_KEY") }

        #expect(Config.spoonacularAPIKey == "abc123")
    }

    @Test func spoonacularAPIKeyTreatsAWhitespaceOnlyEnvironmentVariableAsAbsent() {
        setenv("SPOONACULAR_API_KEY", "   \n", 1)
        defer { unsetenv("SPOONACULAR_API_KEY") }

        // Trimmed to empty, so this must fall through rather than "succeed" with a blank key
        // that would just fail at the server with a confusing error later.
        #expect(Config.spoonacularAPIKey != "   \n")
        #expect(Config.spoonacularAPIKey != "")
    }
}
