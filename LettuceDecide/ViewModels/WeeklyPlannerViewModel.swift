import Foundation
import Combine

@MainActor
final class WeeklyPlannerViewModel: ObservableObject {
    /// One editable row on the planner: a fixed day, and the busyness the cook picks for it.
    struct Day: Identifiable, Equatable {
        let id: Date
        var busyness: BusynessLevel
        var date: Date { id }
    }

    enum State: Equatable {
        case editing
        case generating
        case generated(WeeklyMealPlan)
        case failed(String)
    }

    @Published var days: [Day]
    @Published private(set) var state: State = .editing

    let pantryStore: PantryStoring

    private let recordBusyness: RecordBusynessUseCase
    private let generatePlan: GenerateWeeklyMealPlanUseCase
    private let calendar: Calendar

    init(
        recordBusyness: RecordBusynessUseCase,
        generatePlan: GenerateWeeklyMealPlanUseCase,
        pantryStore: PantryStoring,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.recordBusyness = recordBusyness
        self.generatePlan = generatePlan
        self.pantryStore = pantryStore
        self.calendar = calendar

        let monday = Self.startOfWeek(containing: now, calendar: calendar)
        self.days = (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: monday) else { return nil }
            return Day(id: calendar.startOfDay(for: date), busyness: .normal)
        }
    }

    var isGenerating: Bool { state == .generating }

    /// Records every day's busyness (so the daily quick-pick and a re-open see it), then asks
    /// `GenerateWeeklyMealPlanUseCase` for the plan.
    func generate() async {
        state = .generating

        let entries = days.map {
            ScheduleEntry(date: $0.date, busyness: $0.busyness, calendar: calendar)
        }
        for entry in entries {
            recordBusyness.execute(date: entry.date, busyness: entry.busyness, calendar: calendar)
        }

        do {
            let plan = try await generatePlan.execute(week: entries)
            state = .generated(plan)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            state = .failed(message)
        }
    }

    func backToEditing() {
        state = .editing
    }

    /// The Monday on or before `date`, regardless of the calendar's locale first-weekday.
    static func startOfWeek(containing date: Date, calendar: Calendar) -> Date {
        var calendar = calendar
        calendar.firstWeekday = 2 // Monday
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }
}
