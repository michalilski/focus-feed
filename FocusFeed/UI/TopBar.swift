import SwiftUI

struct TopBar: View {
    @Bindable var store: SessionStore

    @State private var showsStats = false

    private var session: BrowserSession { store.session(for: store.selected) }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: session.goBack) {
                Image(systemName: "chevron.backward")
            }
            .disabled(!session.canGoBack)
            .accessibilityIdentifier("back")

            Picker("Platform", selection: $store.selected) {
                ForEach(Platform.allCases) { platform in
                    Text(PlatformProfile.profile(for: platform).title).tag(platform)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("platformPicker")

            PageMenu(session: session, onShowStats: { showsStats = true })
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
        .sheet(isPresented: $showsStats) {
            FilterStatsView(session: session, onSaveSnapshot: store.saveSnapshot)
        }
    }
}

struct PageMenu: View {
    let session: BrowserSession
    let onShowStats: () -> Void

    private var statsLabel: String {
        let stats = session.stats
        return stats.leakTotal > 0 ? "Filters: \(stats.leakTotal) leaking" : "Filters: \(stats.hiddenTotal) hidden"
    }

    private var statsIcon: String {
        session.stats.leakTotal > 0 ? "exclamationmark.triangle" : "line.3.horizontal.decrease.circle"
    }

    var body: some View {
        Menu {
            Button("Reload", systemImage: "arrow.clockwise", action: session.reload)
            Button("Feed", systemImage: "house", action: session.goHome)
            Button("Forward", systemImage: "chevron.forward", action: session.goForward)
                .disabled(!session.canGoForward)
            Divider()
            Button(statsLabel, systemImage: statsIcon, action: onShowStats)
        } label: {
            Image(systemName: session.stats.leakTotal > 0 ? "exclamationmark.circle" : "ellipsis.circle")
        }
        .accessibilityIdentifier("pageMenu")
    }
}
