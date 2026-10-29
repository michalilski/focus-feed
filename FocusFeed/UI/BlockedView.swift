import SwiftUI

struct BlockedView: View {
    let reason: BlockReason
    let onDismiss: () -> Void

    var body: some View {
        CalmScreen(symbol: "leaf.fill", title: reason.title, message: reason.message) {
            CalmButton(title: "Back to what I came for", action: onDismiss)
                .accessibilityIdentifier("dismissBlock")
        }
        .accessibilityIdentifier("blockedView")
    }
}

struct LoadErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        CalmScreen(symbol: "wifi.slash", title: "Can't load the page", message: message) {
            CalmButton(title: "Try again", action: onRetry)
        }
    }
}

struct TimeNudgeView: View {
    let minutes: Int
    let onSnooze: () -> Void

    var body: some View {
        CalmScreen(
            symbol: "hourglass",
            title: "\(minutes) minutes today",
            message: "Did you find what you came for? This is a good place to stop."
        ) {
            CalmButton(title: "5 more minutes", action: onSnooze)
                .accessibilityIdentifier("snoozeNudge")
        }
        .accessibilityIdentifier("timeNudge")
    }
}
