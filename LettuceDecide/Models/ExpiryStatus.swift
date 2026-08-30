import Foundation

/// How close a pantry ingredient is to being unusable.
///
/// Real-world meaning: the answer to "do I need to worry about this one yet?". It is always
/// derived from the ingredient's expiry date relative to today — never stored — so it can
/// never drift out of sync with the calendar.
///
/// Business rule: an ingredient counts as *expiring soon* when its expiry date is today or
/// within the next 3 days. That 3-day window is the single definition the recommendation
/// ranking uses to decide which ingredients to steer the cook towards using up.
enum ExpiryStatus: Equatable {
    case fresh
    case expiringSoon(daysRemaining: Int)
    case expired

    /// Number of whole calendar days from `now` until the ingredient expires;
    /// classifies as `.expiringSoon` when that value is within this many days.
    static let soonThresholdDays = 3

    init(expiryDate: Date?, asOf now: Date = Date()) {
        guard let expiryDate else {
            self = .fresh
            return
        }
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let startOfExpiry = calendar.startOfDay(for: expiryDate)
        let days = calendar.dateComponents([.day], from: startOfToday, to: startOfExpiry).day ?? 0

        if days < 0 {
            self = .expired
        } else if days <= Self.soonThresholdDays {
            self = .expiringSoon(daysRemaining: days)
        } else {
            self = .fresh
        }
    }

    /// Whether this ingredient is one the cook should be nudged to use up now
    /// (expiring soon, or already past its date).
    var needsUsingUp: Bool {
        switch self {
        case .fresh: return false
        case .expiringSoon, .expired: return true
        }
    }
}
