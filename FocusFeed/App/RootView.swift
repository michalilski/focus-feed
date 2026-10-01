import SwiftUI

struct RootView: View {
    @State private var store = SessionStore()

    var body: some View {
        VStack(spacing: 0) {
            TopBar(store: store)
            ZStack {
                ForEach(store.sessions) { session in
                    BrowserScreen(session: session)
                        .opacity(session.id == store.selected ? 1 : 0)
                        .allowsHitTesting(session.id == store.selected)
                }
            }
        }
        .onAppear { store.apply(LaunchOptions()) }
        .sheet(item: $store.externalPage) { page in
            SafariView(url: page.url).ignoresSafeArea()
        }
    }
}
