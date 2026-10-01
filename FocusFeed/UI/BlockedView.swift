import SwiftUI

struct BlockedView: View {
    let reason: BlockReason
    let onDismiss: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(reason.title, systemImage: "leaf.fill")
        } description: {
            Text(reason.message)
        } actions: {
            Button("Back to what I came for", action: onDismiss)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("dismissBlock")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .accessibilityIdentifier("blockedView")
    }
}

struct LoadErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Can't load the page", systemImage: "wifi.slash")
        } description: {
            Text(message)
        } actions: {
            Button("Try again", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}
