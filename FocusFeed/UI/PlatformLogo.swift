import SwiftUI

struct PlatformLogo: View {
    let platform: Platform
    let isSelected: Bool

    var body: some View {
        Image("logo-\(platform.rawValue)")
            .resizable()
            .scaledToFit()
            .frame(width: 21, height: 21)
            .foregroundStyle(isSelected ? brandStyle : AnyShapeStyle(.secondary))
    }

    private var brandStyle: AnyShapeStyle {
        switch platform {
        case .instagram: AnyShapeStyle(Self.instagramGradient)
        case .youtube: AnyShapeStyle(Color(red: 1, green: 0, blue: 0))
        case .x: AnyShapeStyle(.primary)
        }
    }

    private static let instagramGradient = LinearGradient(
        colors: [
            Color(red: 0.996, green: 0.855, blue: 0.459),
            Color(red: 0.980, green: 0.494, blue: 0.118),
            Color(red: 0.839, green: 0.161, blue: 0.463),
            Color(red: 0.588, green: 0.184, blue: 0.749),
            Color(red: 0.310, green: 0.357, blue: 0.835),
        ],
        startPoint: .bottomLeading,
        endPoint: .topTrailing
    )
}
