import SwiftUI

struct CaughtUpPanel: View {
    let extendable: Bool
    let onExtend: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.tint)
            Text(extendable ? "That's one page" : "You're caught up")
                .font(.headline)
            Text(extendable ? "Refine the search, or load one more page on purpose." : "Nothing newer than this. Go do something else.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if extendable {
                Button("Show one more page", action: onExtend)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("extendCutoff")
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 24)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, minHeight: 2000, alignment: .top)
        .background(.background)
        .accessibilityIdentifier("caughtUpPanel")
    }
}
