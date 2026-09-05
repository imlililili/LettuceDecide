import SwiftUI

/// A thin banner shown above cached recipe content when the network was unreachable and the
/// app fell back to a previously stored result. The cook has a right to know the data's
/// source and freshness — the same honesty principle as the allergen safety rule.
struct StaleResultsNotice: View {
    var body: some View {
        Label(
            "Showing saved results — you're offline, so these may be out of date.",
            systemImage: "wifi.slash"
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.yellow.opacity(0.15))
    }
}

#Preview {
    StaleResultsNotice()
}
