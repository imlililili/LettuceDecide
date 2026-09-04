import Foundation

/// Persists the cook's shopping list so it survives app relaunches.
///
/// Same shape as `PantryStoring` / `ScheduleStoring`.
protocol ShoppingListStoring {
    func loadItems() -> [ShoppingListItem]
    func save(_ items: [ShoppingListItem])
}

/// File-backed `ShoppingListStoring`: one JSON document in Application Support.
///
/// Read and write failures are swallowed and treated as "empty list" / "not saved", the
/// same way `PantryStore` treats a missing or corrupt file.
final class ShoppingListStore: ShoppingListStoring {
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
                .appendingPathComponent("shopping-list.json", isDirectory: false)
        }

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
    }

    func loadItems() -> [ShoppingListItem] {
        guard
            let data = try? Data(contentsOf: fileURL),
            let decoded = try? decoder.decode([ShoppingListItem].self, from: data)
        else {
            return []
        }
        return decoded
    }

    func save(_ items: [ShoppingListItem]) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Best effort: a failed write leaves the previous file in place.
        }
    }
}

/// In-memory `ShoppingListStoring` for previews and tests — never touches the filesystem.
final class InMemoryShoppingListStore: ShoppingListStoring {
    private var stored: [ShoppingListItem]

    init(initial: [ShoppingListItem] = []) {
        self.stored = initial
    }

    func loadItems() -> [ShoppingListItem] { stored }
    func save(_ items: [ShoppingListItem]) { stored = items }
}
