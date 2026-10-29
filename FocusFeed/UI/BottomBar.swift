import SwiftUI

struct BottomBar: View {
    @Bindable var store: SessionStore
    let onHide: () -> Void

    @State private var showsStats = false

    private var session: BrowserSession { store.session(for: store.selected) }

    var body: some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 6) {
                BarIconButton(symbol: "chevron.backward", action: session.goBack)
                    .disabled(!session.canGoBack)
                    .accessibilityIdentifier("back")
                Spacer(minLength: 0)
                PlatformSwitcher(selection: $store.selected)
                Spacer(minLength: 0)
                BarIconButton(symbol: "chevron.down", action: onHide)
                    .accessibilityIdentifier("hideBar")
                PageMenu(session: session, onShowStats: { showsStats = true })
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .simultaneousGesture(swipeDownToHide)
        .sheet(isPresented: $showsStats) {
            FilterStatsView(session: session, onSaveSnapshot: store.saveSnapshot)
        }
    }

    private var swipeDownToHide: some Gesture {
        DragGesture(minimumDistance: 20).onEnded { drag in
            if drag.translation.height > 30 { onHide() }
        }
    }
}

struct BarHandle: View {
    let onShow: () -> Void

    var body: some View {
        Capsule()
            .fill(.secondary.opacity(0.6))
            .frame(width: 40, height: 5)
            .frame(maxWidth: .infinity, minHeight: 20)
            .contentShape(.rect)
            .onTapGesture(perform: onShow)
            .gesture(DragGesture(minimumDistance: 10).onEnded { drag in
                if drag.translation.height < -15 { onShow() }
            })
            .accessibilityElement()
            .accessibilityLabel("Show bar")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onShow() }
            .accessibilityIdentifier("showBar")
    }
}

struct BarIconButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .frame(width: 46, height: 46)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
    }
}

struct PlatformSwitcher: View {
    @Binding var selection: Platform

    @Namespace private var highlight

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Platform.allCases) { platform in
                segment(for: PlatformProfile.profile(for: platform))
            }
        }
        .padding(4)
        .glassEffect(.regular.interactive(), in: .capsule)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func segment(for profile: PlatformProfile) -> some View {
        let isSelected = profile.platform == selection
        return Button {
            withAnimation(.smooth(duration: 0.3)) { selection = profile.platform }
        } label: {
            PlatformLogo(platform: profile.platform, isSelected: isSelected)
                .padding(.horizontal, 14)
                .frame(minWidth: 54, minHeight: 38)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(.primary.opacity(0.08))
                            .matchedGeometryEffect(id: "highlight", in: highlight)
                    }
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(profile.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("platform-\(profile.platform.rawValue)")
    }
}

struct PageMenu: View {
    let session: BrowserSession
    let onShowStats: () -> Void

    private var isLeaking: Bool { session.stats.leakTotal > 0 }

    private var statsLabel: String {
        let stats = session.stats
        return isLeaking ? "Filters: \(stats.leakTotal) leaking" : "Filters: \(stats.hiddenTotal) hidden"
    }

    var body: some View {
        Menu {
            Button("Feed", systemImage: "house", action: session.goHome)
            Button("Reload", systemImage: "arrow.clockwise", action: session.reload)
            Button("Forward", systemImage: "chevron.forward", action: session.goForward)
                .disabled(!session.canGoForward)
            Divider()
            Button(statsLabel, systemImage: isLeaking ? "exclamationmark.triangle" : "line.3.horizontal.decrease", action: onShowStats)
        } label: {
            Image(systemName: isLeaking ? "exclamationmark.triangle.fill" : "ellipsis")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(isLeaking ? AnyShapeStyle(.orange) : AnyShapeStyle(.primary))
                .frame(width: 46, height: 46)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityIdentifier("pageMenu")
    }
}
