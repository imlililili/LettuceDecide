import Foundation

/// Reads the Spoonacular API key without ever hardcoding it in source.
///
/// Resolution order:
/// 1. The `SPOONACULAR_API_KEY` environment variable (set on the Xcode scheme, or in CI).
/// 2. `Resources/Config.plist` — a local, git-ignored file. Copy
///    `Resources/Config.example.plist` to `Resources/Config.plist` and fill in your key.
enum Config {
    enum ConfigError: LocalizedError {
        case missingAPIKey

        var errorDescription: String? {
            "No Spoonacular API key found. Set the SPOONACULAR_API_KEY environment variable " +
            "on the run scheme, or copy Resources/Config.example.plist to Resources/Config.plist " +
            "and fill in your key."
        }
    }

    static var spoonacularAPIKey: String? {
        if let envKey = ProcessInfo.processInfo.environment["SPOONACULAR_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        guard
            let url = Bundle.main.url(forResource: "Config", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            let key = plist["SpoonacularAPIKey"] as? String,
            !key.isEmpty,
            key != "YOUR_API_KEY_HERE"
        else {
            return nil
        }
        return key
    }

    static func requireAPIKey() throws -> String {
        guard let key = spoonacularAPIKey else { throw ConfigError.missingAPIKey }
        return key
    }
}
