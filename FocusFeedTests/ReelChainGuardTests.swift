import XCTest
@testable import FocusFeed

final class ReelChainGuardTests: XCTestCase {
    private let thread = URL(string: "https://www.instagram.com/direct/t/123/")!
    private let reel = URL(string: "https://www.instagram.com/reel/Cabc_123/")!
    private let nextReel = URL(string: "https://www.instagram.com/reels/Cnext_456/")!
    private let userReel = URL(string: "https://www.instagram.com/someone/reel/Cother_789/")!

    func testOpeningAReelFromAThreadIsAllowed() {
        var reelGuard = ReelChainGuard()
        XCTAssertTrue(reelGuard.allows(thread, isClientSide: false))
        XCTAssertTrue(reelGuard.allows(reel, isClientSide: true))
    }

    func testSwipingToAnotherReelIsRefused() {
        var reelGuard = ReelChainGuard()
        _ = reelGuard.allows(reel, isClientSide: false)
        XCTAssertFalse(reelGuard.allows(nextReel, isClientSide: true))
        XCTAssertFalse(reelGuard.allows(userReel, isClientSide: true))
    }

    func testReturningToTheSameReelIsAllowed() {
        var reelGuard = ReelChainGuard()
        _ = reelGuard.allows(reel, isClientSide: false)
        _ = reelGuard.allows(nextReel, isClientSide: true)
        XCTAssertTrue(reelGuard.allows(URL(string: "https://www.instagram.com/reels/Cabc_123/")!, isClientSide: true))
    }

    func testLeavingTheReelResetsTheChain() {
        var reelGuard = ReelChainGuard()
        _ = reelGuard.allows(reel, isClientSide: false)
        XCTAssertTrue(reelGuard.allows(thread, isClientSide: true))
        XCTAssertTrue(reelGuard.allows(nextReel, isClientSide: true))
    }

    func testPageLoadOfAnotherReelIsAllowed() {
        var reelGuard = ReelChainGuard()
        _ = reelGuard.allows(reel, isClientSide: false)
        XCTAssertTrue(reelGuard.allows(userReel, isClientSide: false))
    }

    func testAudioPageIsNotAReel() {
        XCTAssertNil(ReelChainGuard.reelID(in: URL(string: "https://www.instagram.com/reels/audio/12345/")!))
        XCTAssertEqual(ReelChainGuard.reelID(in: userReel), "Cother_789")
    }
}
