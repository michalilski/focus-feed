import SwiftUI

struct RootView: View {
    @State private var store = SessionStore()
    @State private var today = DailyTracker()
    @AppStorage("barHidden") private var barHidden = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            TodayLabel(minutes: today.minutes)
            pages
            bar
        }
        .background(.background)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(.smooth(duration: 0.3), value: barHidden)
        .onAppear { store.apply(LaunchOptions()) }
        .onChange(of: scenePhase, initial: true) { trackTime(scenePhase) }
        .onChange(of: today.showsNudge) { if today.showsNudge { store.pauseSelected() } }
        .sheet(item: $store.externalPage) { page in
            SafariView(url: page.url).ignoresSafeArea()
        }
    }

    private var pages: some View {
        ZStack {
            ForEach(store.sessions) { session in
                BrowserScreen(session: session)
                    .opacity(session.id == store.selected ? 1 : 0)
                    .allowsHitTesting(session.id == store.selected)
            }
            if today.showsNudge {
                TimeNudgeView(minutes: today.minutes, onSnooze: today.snooze)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: today.showsNudge)
    }

    @ViewBuilder
    private var bar: some View {
        if barHidden {
            BarHandle { barHidden = false }
                .transition(.opacity)
        } else {
            BottomBar(store: store) { barHidden = true }
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func trackTime(_ phase: ScenePhase) {
        if phase == .active {
            today.resume()
        } else {
            today.suspend()
        }
    }
}
