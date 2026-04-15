import XCTest
@testable import SSHub

final class HostModelTests: XCTestCase {
    func testHostDraftIsValidWithRequiredFieldsOnly() {
        var draft = HostDraft()
        draft.name = "celegans"
        draft.hostAlias = "celegans"

        XCTAssertTrue(draft.isValid)
    }

    func testHostDraftRejectsInvalidPortOverride() {
        var draft = HostDraft()
        draft.name = "celegans"
        draft.hostAlias = "celegans"
        draft.portText = "70000"

        XCTAssertFalse(draft.isValid)
    }

    func testMakeHostTrimsWhitespaceAndOmitsEmptyOverrides() {
        var draft = HostDraft()
        draft.name = "  celegans  "
        draft.hostAlias = "  celegans-login  "
        draft.username = "   "
        draft.portText = ""

        let host = draft.makeHost()

        XCTAssertEqual(host.name, "celegans")
        XCTAssertEqual(host.hostAlias, "celegans-login")
        XCTAssertNil(host.username)
        XCTAssertNil(host.port)
        XCTAssertEqual(host.status, .unknown)
        XCTAssertNil(host.lastCheckedAt)
    }

    func testDisplayTargetUsesUserAndPortWhenPresent() {
        let host = Host(
            id: UUID(),
            name: "cluster",
            hostAlias: "login-node",
            username: "iwamoto",
            port: 2222,
            status: .unknown,
            statusMessage: nil,
            lastCheckedAt: nil
        )

        XCTAssertEqual(host.displayTarget, "iwamoto@login-node:2222")
    }

    func testDisplayTargetWithoutOverridesShowsHostOnly() {
        let host = Host(
            id: UUID(),
            name: "cluster",
            hostAlias: "login-node",
            username: nil,
            port: nil,
            status: .unknown,
            statusMessage: nil,
            lastCheckedAt: nil
        )

        XCTAssertEqual(host.displayTarget, "login-node")
    }

    func testMakeDraftRestoresOverrideStrings() {
        let host = Host(
            id: UUID(),
            name: "cluster",
            hostAlias: "login-node",
            username: "iwamoto",
            port: 2222,
            status: .reachable,
            statusMessage: nil,
            lastCheckedAt: Date(timeIntervalSince1970: 0)
        )

        let draft = host.makeDraft()

        XCTAssertEqual(draft.name, "cluster")
        XCTAssertEqual(draft.hostAlias, "login-node")
        XCTAssertEqual(draft.username, "iwamoto")
        XCTAssertEqual(draft.portText, "2222")
    }

    func testDisplayStatusMessageHidesGenericReachableSuccessText() {
        let host = Host(
            id: UUID(),
            name: "cluster",
            hostAlias: "login-node",
            username: nil,
            port: nil,
            status: .reachable,
            statusMessage: "ok",
            lastCheckedAt: nil
        )

        XCTAssertNil(host.displayStatusMessage)
    }

    func testDisplayStatusMessageShowsMeaningfulFailureText() {
        let host = Host(
            id: UUID(),
            name: "cluster",
            hostAlias: "login-node",
            username: nil,
            port: nil,
            status: .unreachable,
            statusMessage: "Connection timed out",
            lastCheckedAt: nil
        )

        XCTAssertEqual(host.displayStatusMessage, "Connection timed out")
    }

    func testHostStatusDecodesLegacyConnectedAsReachable() throws {
        let data = Data(#""connected""#.utf8)

        let status = try JSONDecoder().decode(HostStatus.self, from: data)

        XCTAssertEqual(status, .reachable)
    }

    func testHostStatusDecodesLegacyDisconnectedAsUnreachable() throws {
        let data = Data(#""disconnected""#.utf8)

        let status = try JSONDecoder().decode(HostStatus.self, from: data)

        XCTAssertEqual(status, .unreachable)
    }
}
