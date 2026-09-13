import Foundation
import Combine

/// Persists the cook's confirmed Week Plan meals so the Home dashboard and its shopping list
/// survive app relaunches.
///
/// Same shape as `PantryStoring` / `ScheduleStoring` / `ShoppingListStoring`: the protocol
/// exists so use cases depend on the behaviour, not the storage.
protocol ConfirmedMealStoring {
    func loadConfirmedMeals() -> [ConfirmedMeal]
    /// Records `meal`, replacing any existing entry for the same day (see `ConfirmedMeal.id`).
    func confirm(_ meal: ConfirmedMeal)
    /// Removes the confirmed meal for `date`, if any. A no-op if that day has no entry.
    func removeConfirmedMeal(for date: Date)

    /// Fires once after every successful `confirm` or `removeConfirmedMeal` — same contract as
    /// `PantryStoring.changes`. Home shows confirmed meals on its own tab's `NavigationStack`,
    /// so a card can be removed from a screen Home never reloads on return to (e.g. "Mark as
    /// Cooked" surfacing a manual-review notice keeps Recipe Detail on screen); subscribing
    /// here is what lets the card disappear the moment it happens rather than only on the next
    /// tab switch.
    ///
    /// Delivered synchronously on the caller's thread. Every mutation in the app goes through
    /// the main actor, so a main-actor subscriber can update its state directly.
    var changes: AnyPublisher<Void, Never> { get }
}

/// File-backed `ConfirmedMealStoring`: one JSON document in Application Support.
///
/// Read and write failures are swallowed and treated as "nothing confirmed" / "not saved",
/// the same way `PantryStore` treats a missing or corrupt file — the app stays usable rather
/// than crashing.
final class ConfirmedMealStore: ConfirmedMealStoring {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let changeSubject = PassthroughSubject<Void, Never>()

    var changes: AnyPublisher<Void, Never> { changeSubject.eraseToAnyPublisher() }

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
                .appendingPathComponent("confirmed-meals.json", isDirectory: false)
        }

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
    }

    func loadConfirmedMeals() -> [ConfirmedMeal] {
        guard
            let data = try? Data(contentsOf: fileURL),
            let decoded = try? decoder.decode([ConfirmedMeal].self, from: data)
        else {
            return []
        }
        return decoded
    }

    func confirm(_ meal: ConfirmedMeal) {
        var meals = loadConfirmedMeals()
        meals.removeAll { $0.id == meal.id }
        meals.append(meal)
        save(meals)
    }

    func removeConfirmedMeal(for date: Date) {
        var meals = loadConfirmedMeals()
        let key = Calendar.current.startOfDay(for: date)
        meals.removeAll { $0.id == key }
        save(meals)
    }

    private func save(_ meals: [ConfirmedMeal]) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(meals)
            try data.write(to: fileURL, options: .atomic)
            changeSubject.send()
        } catch {
            // Best effort: a failed write leaves the previous file in place and does not
            // announce a change.
        }
    }
}

/// In-memory `ConfirmedMealStoring` for previews and tests — never touches the filesystem.
final class InMemoryConfirmedMealStore: ConfirmedMealStoring {
    private var stored: [ConfirmedMeal]
    private let changeSubject = PassthroughSubject<Void, Never>()

    var changes: AnyPublisher<Void, Never> { changeSubject.eraseToAnyPublisher() }

    init(initial: [ConfirmedMeal] = []) {
        self.stored = initial
    }

    func loadConfirmedMeals() -> [ConfirmedMeal] { stored }

    func confirm(_ meal: ConfirmedMeal) {
        stored.removeAll { $0.id == meal.id }
        stored.append(meal)
        changeSubject.send()
    }

    func removeConfirmedMeal(for date: Date) {
        let key = Calendar.current.startOfDay(for: date)
        stored.removeAll { $0.id == key }
        changeSubject.send()
    }
}
