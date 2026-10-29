import SwiftUI

struct TodayLabel: View {
    let minutes: Int

    var body: some View {
        Text("Today · \(minutes) min")
            .font(.caption.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .contentTransition(.numericText())
            .animation(.smooth, value: minutes)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 4)
            .accessibilityIdentifier("todayLabel")
    }
}
