import SwiftUI

/// The one layout for every message the app shows over a page.
struct CalmCard<Actions: View>: View {
    let symbol: String
    let title: String
    let message: String
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 64, height: 64)
                .glassEffect(.regular, in: .circle)
            VStack(spacing: 6) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            actions()
                .padding(.top, 4)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: 420)
    }
}

struct CalmScreen<Actions: View>: View {
    let symbol: String
    let title: String
    let message: String
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        CalmCard(symbol: symbol, title: title, message: message, actions: actions)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.background)
    }
}

struct CalmButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
        .buttonStyle(.glass)
    }
}
