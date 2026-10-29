import SwiftUI

struct CaughtUpPanel: View {
    let extendable: Bool
    let onExtend: () -> Void

    var body: some View {
        CalmCard(
            symbol: extendable ? "magnifyingglass" : "checkmark",
            title: extendable ? "That's one page" : "You're caught up",
            message: extendable ? "Refine the search, or load one more page on purpose." : "Nothing newer than this. Go do something else."
        ) {
            if extendable {
                Button("Show one more page", action: onExtend)
                    .buttonStyle(.glass)
                    .accessibilityIdentifier("extendCutoff")
            }
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity, minHeight: 2000, alignment: .top)
        .background(.background)
        .accessibilityIdentifier("caughtUpPanel")
    }
}
