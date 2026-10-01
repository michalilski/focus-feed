import Foundation

enum Platform: String, CaseIterable, Identifiable {
    case instagram
    case youtube
    case x

    var id: String { rawValue }
}
