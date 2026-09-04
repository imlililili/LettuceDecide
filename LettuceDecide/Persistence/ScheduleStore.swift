import Foundation

/// Persists the cook's recorded busyness so it survives app relaunches.
///
/// Same shape as `PantryStoring` / `UserPreferencesStoring`: the protocol exists so use
/// cases depend on the behaviour, not the storage.
protocol ScheduleStoring {
    func loadEntries() -> [ScheduleEntry]
    func save(_ entries: [ScheduleEntry])
}

/// File-backed `ScheduleStoring`: one JSON document in Application Support.
///
/// Read and write failures are swallowed and treated as "no schedule recorded" / "not
/// saved", the same way `PantryStore` treats a missing or corrupt file — the app stays
/// usable rather than crashing.
final class ScheduleStore: ScheduleStoring {
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
                .appendingPathComponent("schedule.json", isDirectory: false)
        }

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
    }

    func loadEntries() -> [ScheduleEntry] {
        guard
            let data = try? Data(contentsOf: fileURL),
            let decoded = try? decoder.decode([ScheduleEntry].self, from: data)
        else {
            return []
        }
        return decoded
    }

    func save(_ entries: [ScheduleEntry]) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Best effort: a failed write leaves the previous file in place.
        }
    }
}

/// In-memory `ScheduleStoring` for previews and tests — never touches the filesystem.
final class InMemoryScheduleStore: ScheduleStoring {
    private var stored: [ScheduleEntry]

    init(initial: [ScheduleEntry] = []) {
        self.stored = initial
    }

    func loadEntries() -> [ScheduleEntry] { stored }
    func save(_ entries: [ScheduleEntry]) { stored = entries }
}
