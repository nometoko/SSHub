import XCTest
@testable import SSHub

final class SSHServiceTests: XCTestCase {
    func testConnectivityCheckArgumentsUseHostAliasOnlyWhenNoOverridesExist() {
        let host = Host(
            id: UUID(),
            name: "celegans",
            hostAlias: "celegans",
            username: nil,
            port: nil,
            status: .unknown,
            statusMessage: nil,
            lastCheckedAt: nil
        )

        XCTAssertEqual(
            SSHService.connectivityCheckArguments(for: host),
            ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=5", "celegans", "echo", "ok"]
        )
    }

    func testConnectivityCheckArgumentsIncludeUserAndPortOverrides() {
        let host = Host(
            id: UUID(),
            name: "celegans",
            hostAlias: "celegans",
            username: "iwamoto",
            port: 2201,
            status: .unknown,
            statusMessage: nil,
            lastCheckedAt: nil
        )

        XCTAssertEqual(
            SSHService.connectivityCheckArguments(for: host),
            ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=5", "-p", "2201", "-l", "iwamoto", "celegans", "echo", "ok"]
        )
    }
}
