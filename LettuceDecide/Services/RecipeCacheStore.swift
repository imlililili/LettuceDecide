import Foundation

/// Stores the last successful recipe-search result per query so it can be served back when
/// the network is unreachable.
///
/// The `key` is the caller's — normally derived from the pantry ingredient names plus the
/// dietary preferences, so only an identical query hits the cache
/// (`CachingRecipeRepository.cacheKey`).
protocol RecipeCacheStoring {
    func loadCachedCandidates(forKey key: String) -> [PantryRecipeCandidate]?
    func save(_ candidates: [PantryRecipeCandidate], forKey key: String)
}

/// File-backed `RecipeCacheStoring`: one JSON document, keyed by query, in Application
/// Support — the same Codable-file pattern as `PantryStore` / `ScheduleStore`. Deliberately
/// not SwiftData: this project has no SwiftData, and a cache is not the place to introduce a
/// second persistence technology.
///
/// Read and write failures are swallowed (treated as "no cache") the same way the other
/// stores treat a missing or corrupt file.
final class RecipeCacheStore: RecipeCacheStoring {
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
                .appendingPathComponent("recipe-cache.json", isDirectory: false)
        }

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
    }

    func loadCachedCandidates(forKey key: String) -> [PantryRecipeCandidate]? {
        loadAll()[key]
    }

    func save(_ candidates: [PantryRecipeCandidate], forKey key: String) {
        var all = loadAll()
        all[key] = candidates
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(all)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Best effort: a failed write leaves the previous cache in place.
        }
    }

    private func loadAll() -> [String: [PantryRecipeCandidate]] {
        guard
            let data = try? Data(contentsOf: fileURL),
            let decoded = try? decoder.decode([String: [PantryRecipeCandidate]].self, from: data)
        else {
            return [:]
        }
        return decoded
    }
}

/// In-memory `RecipeCacheStoring` for previews and tests — never touches the filesystem.
final class InMemoryRecipeCacheStore: RecipeCacheStoring {
    private var stored: [String: [PantryRecipeCandidate]]

    init(initial: [String: [PantryRecipeCandidate]] = [:]) {
        self.stored = initial
    }

    func loadCachedCandidates(forKey key: String) -> [PantryRecipeCandidate]? { stored[key] }
    func save(_ candidates: [PantryRecipeCandidate], forKey key: String) { stored[key] = candidates }
}
