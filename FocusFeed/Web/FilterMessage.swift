import Foundation

struct FilterStats: Equatable {
    var hidden: [String: Int] = [:]
    var leaks: [String: Int] = [:]

    var hiddenTotal: Int { hidden.values.filter { $0 > 0 }.reduce(0, +) }
    var leakTotal: Int { leaks.values.filter { $0 > 0 }.reduce(0, +) }
}

struct Cutoff: Equatable {
    let y: Double
    let extendable: Bool
}

enum FilterMessage: Equatable {
    case stats(FilterStats)
    case cutoff(Cutoff?)

    init?(body: Any) {
        guard let payload = body as? [String: Any], let type = payload["type"] as? String else { return nil }
        switch type {
        case "stats":
            guard let counts = payload["counts"] as? [String: Int] else { return nil }
            self = .stats(FilterStats(hidden: counts, leaks: payload["leaks"] as? [String: Int] ?? [:]))
        case "cutoff":
            self = .cutoff(Self.cutoff(from: payload))
        default:
            return nil
        }
    }

    private static func cutoff(from payload: [String: Any]) -> Cutoff? {
        guard let y = (payload["y"] as? NSNumber)?.doubleValue, y >= 0 else { return nil }
        return Cutoff(y: y, extendable: payload["extendable"] as? Bool ?? false)
    }
}
