import Foundation

struct BlockReason: Equatable {
    let title: String
    let message: String
}

enum RouteDecision: Equatable {
    case allow
    case redirect(URL)
    case block(BlockReason)
    case external
    case cancel
}
