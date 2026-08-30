import SwiftUI

/// A recoverable-error panel. The recovery action is not always "retry" — some errors
/// (an empty pantry) need the user sent somewhere else — so the button title and handler
/// are supplied by the caller.
struct ErrorStateView: View {
    let message: String
    var actionTitle: String = "Try Again"
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    ErrorStateView(message: "No recipes matched those settings.") {}
}
