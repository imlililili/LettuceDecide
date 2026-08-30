import Foundation

/// Persists the cook's pantry inventory so it survives app relaunches.
///
/// The MVP implementation writes a JSON file. The protocol exists so use cases depend on
/// the behaviour, not the storage: a SwiftData-backed store can later sit behind this same
/// interface without any use case changing.
protocol PantryStoring {
    func load() -> [PantryIngredient]
    func save(_ ingredients: [PantryIngredient])
}

/// File-backed `PantryStoring`: one JSON document in Application Support.
///
/// Read and write failures are swallowed and treated as "empty pantry" / "not saved" the
/// same way `UserPreferencesStore` treats a missing defaults value — the app stays usable
/// rather than crashing on a corrupt file.
final class PantryStore: PantryStoring {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = (try? FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )) ?? FileManager.default.temporaryDirectory
            self.fileURL = base
                .appendingPathComponent("FridgeFit", isDirectory: true)
                .appendingPathComponent("pantry.json", isDirectory: false)
        }

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
    }

    func load() -> [PantryIngredient] {
        guard
            let data = try? Data(contentsOf: fileURL),
            let decoded = try? decoder.decode([PantryIngredient].self, from: data)
        else {
            return []
        }
        return decoded
    }

    func save(_ ingredients: [PantryIngredient]) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(ingredients)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Best effort: a failed write leaves the previous file in place.
        }
    }
}

/// In-memory `PantryStoring` for previews and tests — never touches the filesystem.
final class InMemoryPantryStore: PantryStoring {
    private var stored: [PantryIngredient]

    init(initial: [PantryIngredient] = []) {
        self.stored = initial
    }

    func load() -> [PantryIngredient] { stored }
    func save(_ ingredients: [PantryIngredient]) { stored = ingredients }
}
