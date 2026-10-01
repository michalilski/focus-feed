import XCTest
@testable import FocusFeed

class RouterTestCase: XCTestCase {
    var profile: PlatformProfile { fatalError("Override in subclass") }

    func decide(_ string: String) -> RouteDecision {
        Router(profile: profile).decide(URL(string: string)!)
    }

    func assertAllowed(_ string: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(decide(string), .allow, string, file: file, line: line)
    }

    func assertRedirect(_ string: String, to target: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(decide(string), .redirect(URL(string: target)!), string, file: file, line: line)
    }

    func assertBlocked(_ string: String, file: StaticString = #filePath, line: UInt = #line) {
        guard case .block = decide(string) else {
            return XCTFail("Expected block for \(string), got \(decide(string))", file: file, line: line)
        }
    }

    func assertExternal(_ string: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(decide(string), .external, string, file: file, line: line)
    }
}
