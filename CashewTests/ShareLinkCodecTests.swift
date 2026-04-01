import Foundation
import XCTest
@testable import Cashew

@MainActor
final class ShareLinkCodecTests: XCTestCase {

    func testMakeInviteURLAndParseRoundTrip() throws {
        let token = "abc 123/+=?"
        let url = try ShareLinkCodec.makeInviteURL(token: token)

        XCTAssertEqual(url.scheme, "cashew")
        XCTAssertEqual(url.host, "join")
        XCTAssertEqual(ShareLinkCodec.parseInviteToken(from: url), token)
        XCTAssertTrue(url.absoluteString.contains("%2F"))
    }

    func testParseInviteTokenRejectsInvalidURLShapes() {
        XCTAssertNil(ShareLinkCodec.parseInviteToken(from: URL(string: "https://example.com/join/abc")!))
        XCTAssertNil(ShareLinkCodec.parseInviteToken(from: URL(string: "cashew://other/abc")!))
        XCTAssertNil(ShareLinkCodec.parseInviteToken(from: URL(string: "cashew://join")!))
        XCTAssertNil(ShareLinkCodec.parseInviteToken(from: URL(string: "cashew://join/")!))
    }
}
