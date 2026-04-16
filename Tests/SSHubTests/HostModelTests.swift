import XCTest
@testable import SSHub

final class HostModelTests: XCTestCase {
    func testSidebarSectionTitlesMatchRawValues() {
        XCTAssertEqual(SidebarSection.dashboard.id, "dashboard")
        XCTAssertEqual(SidebarSection.dashboard.title, "Dashboard")
        XCTAssertEqual(SidebarSection.hosts.title, "Hosts")
        XCTAssertEqual(SidebarSection.jobs.title, "Jobs")
        XCTAssertEqual(SidebarSection.settings.title, "Settings")
    }

    func testHostDraftIsValidWithRequiredFieldsOnly() {
        var draft = HostDraft()
        draft.name = "celegans"
        draft.hostAlias = "celegans"

        XCTAssertTrue(draft.isValid)
    }

    func testHostDraftRejectsMissingRequiredFields() {
        XCTAssertFalse(HostDraft().isValid)

        var draft = HostDraft()
        draft.name = "celegans"
        XCTAssertFalse(draft.isValid)

        draft.name = ""
        draft.hostAlias = "celegans"
        XCTAssertFalse(draft.isValid)
    }

    func testHostDraftRejectsInvalidPortOverride() {
        var draft = HostDraft()
        draft.name = "celegans"
        draft.hostAlias = "celegans"
        draft.portText = "70000"

        XCTAssertFalse(draft.isValid)
    }

    func testHostDraftRejectsNonNumericPortOverride() {
        var draft = HostDraft()
        draft.name = "celegans"
        draft.hostAlias = "celegans"
        draft.portText = "ssh"

        XCTAssertFalse(draft.isValid)
    }

    func testHostDraftAcceptsBoundaryPortOverride() {
        var draft = HostDraft()
        draft.name = "celegans"
        draft.hostAlias = "celegans"
        draft.portText = "65535"

        XCTAssertTrue(draft.isValid)
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

    func testMakeHostPreservesUsernameAndPortOverrides() {
        var draft = HostDraft()
        draft.name = "celegans"
        draft.hostAlias = "celegans-login"
        draft.username = " iwamoto "
        draft.portText = " 2222 "

        let host = draft.makeHost()

        XCTAssertEqual(host.username, "iwamoto")
        XCTAssertEqual(host.port, 2222)
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

    func testDisplayStatusMessageHidesEmptyMessage() {
        let host = Host(
            id: UUID(),
            name: "cluster",
            hostAlias: "login-node",
            username: nil,
            port: nil,
            status: .unknown,
            statusMessage: "",
            lastCheckedAt: nil
        )

        XCTAssertNil(host.displayStatusMessage)
    }

    func testDisplayStatusMessageHidesReachabilitySuccessWithWhitespace() {
        let host = Host(
            id: UUID(),
            name: "cluster",
            hostAlias: "login-node",
            username: nil,
            port: nil,
            status: .reachable,
            statusMessage: "  Reachability check OK \n",
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

    func testHostStatusDecodesOtherCasesAndEncodesRawValue() throws {
        XCTAssertEqual(try JSONDecoder().decode(HostStatus.self, from: Data(#""checking""#.utf8)), .checking)
        XCTAssertEqual(try JSONDecoder().decode(HostStatus.self, from: Data(#""unreachable""#.utf8)), .unreachable)
        XCTAssertEqual(try JSONDecoder().decode(HostStatus.self, from: Data(#""unknown""#.utf8)), .unknown)
        XCTAssertEqual(try JSONDecoder().decode(HostStatus.self, from: Data(#""mystery""#.utf8)), .unknown)

        let encoded = try JSONEncoder().encode(HostStatus.reachable)
        XCTAssertEqual(String(data: encoded, encoding: .utf8), #""reachable""#)
    }

    func testHostWithStatusOverridesMutableFieldsOnly() {
        let checkedAt = Date(timeIntervalSince1970: 1234)
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

        let updated = host.withStatus(.reachable, message: "ok", lastCheckedAt: checkedAt)

        XCTAssertEqual(updated.id, host.id)
        XCTAssertEqual(updated.name, host.name)
        XCTAssertEqual(updated.hostAlias, host.hostAlias)
        XCTAssertEqual(updated.username, host.username)
        XCTAssertEqual(updated.port, host.port)
        XCTAssertEqual(updated.status, .reachable)
        XCTAssertEqual(updated.statusMessage, "ok")
        XCTAssertEqual(updated.lastCheckedAt, checkedAt)
    }

    func testTmuxSessionHelpersUseIdentifierBasedMatching() {
        let host = Host(
            id: UUID(),
            name: "gpu-01",
            hostAlias: "gpu-01",
            username: nil,
            port: nil,
            status: .reachable,
            statusMessage: nil,
            lastCheckedAt: nil
        )
        let session = TmuxSession(
            id: UUID(),
            hostID: host.id,
            hostName: host.name,
            name: "vision-lab",
            workingDirectory: "~/workspace",
            status: .attached,
            createdAt: Date(timeIntervalSince1970: 10),
            lastAttachedAt: Date(timeIntervalSince1970: 20)
        )

        XCTAssertTrue(session.isHostAvailable(in: [host]))
        XCTAssertEqual(session.makeDraft().name, "vision-lab")
        XCTAssertEqual(session.makeDraft().hostID, host.id)
        XCTAssertEqual(session.makeDraft().workingDirectory, "~/workspace")
    }

    func testTmuxSessionDraftHelpersNormalizeAgainstCurrentHosts() {
        let firstHost = Host(
            id: UUID(),
            name: "gpu-01",
            hostAlias: "gpu-01",
            username: nil,
            port: nil,
            status: .unknown,
            statusMessage: nil,
            lastCheckedAt: nil
        )
        let secondHost = Host(
            id: UUID(),
            name: "gpu-02",
            hostAlias: "gpu-02",
            username: nil,
            port: nil,
            status: .unknown,
            statusMessage: nil,
            lastCheckedAt: nil
        )

        XCTAssertNil(TmuxSessionDraft().normalizedHostID(in: []))
        XCTAssertEqual(TmuxSessionDraft().normalizedHostID(in: [firstHost, secondHost]), firstHost.id)
        XCTAssertEqual(TmuxSessionDraft(hostID: secondHost.id).normalizedHostID(in: [firstHost, secondHost]), secondHost.id)

        let staleDraft = TmuxSessionDraft(hostID: UUID())
        XCTAssertEqual(staleDraft.normalizedHostID(in: [firstHost]), staleDraft.hostID)
        XCTAssertTrue(TmuxSessionDraft(hostID: firstHost.id).selectedHostExists(in: [firstHost]))
        XCTAssertFalse(staleDraft.selectedHostExists(in: [firstHost]))
        XCTAssertFalse(TmuxSessionDraft().selectedHostExists(in: [firstHost]))
    }

    func testJobDraftRequiresHostNameAndCommand() {
        var draft = JobDraft()
        draft.name = "train-resnet50"
        draft.command = "python train.py"

        XCTAssertFalse(draft.isValid)

        draft.hostID = UUID()
        XCTAssertFalse(draft.isValid)

        draft.sessionID = UUID()
        XCTAssertTrue(draft.isValid)
    }

    func testJobDraftNormalizedHostIDKeepsExistingHost() {
        let selectedHost = Host(
            id: UUID(),
            name: "gpu-01",
            hostAlias: "gpu-01",
            username: nil,
            port: nil,
            status: .unknown,
            statusMessage: nil,
            lastCheckedAt: nil
        )
        let draft = JobDraft(hostID: selectedHost.id)

        XCTAssertEqual(draft.normalizedHostID(in: [selectedHost]), selectedHost.id)
    }

    func testJobDraftNormalizedHostIDFallsBackWhenStale() {
        let fallbackHost = Host(
            id: UUID(),
            name: "sim-lab",
            hostAlias: "sim-lab",
            username: nil,
            port: nil,
            status: .unknown,
            statusMessage: nil,
            lastCheckedAt: nil
        )
        let staleDraft = JobDraft(hostID: UUID())

        XCTAssertEqual(staleDraft.normalizedHostID(in: [fallbackHost]), staleDraft.hostID)
        XCTAssertNil(staleDraft.normalizedHostID(in: []))
    }

    func testJobDraftSelectedHostExistsChecksCurrentHosts() {
        let host = Host(
            id: UUID(),
            name: "gpu-01",
            hostAlias: "gpu-01",
            username: nil,
            port: nil,
            status: .unknown,
            statusMessage: nil,
            lastCheckedAt: nil
        )
        let draft = JobDraft(hostID: host.id)
        let staleDraft = JobDraft(hostID: UUID())

        XCTAssertTrue(draft.selectedHostExists(in: [host]))
        XCTAssertFalse(staleDraft.selectedHostExists(in: [host]))
        XCTAssertFalse(JobDraft().selectedHostExists(in: [host]))
    }

    func testJobMakeDraftRestoresEditableFields() {
        let hostID = UUID()
        let sessionID = UUID()
        let job = Job(
            id: UUID(),
            name: "train-resnet50",
            hostID: hostID,
            hostName: "gpu-01",
            sessionID: sessionID,
            sessionName: "vision-lab",
            status: .running,
            progressSummary: "Epoch 2/10",
            startedAt: Date(timeIntervalSince1970: 100),
            command: "python train.py",
            workingDirectory: "~/project",
            pid: 12345
        )

        let draft = job.makeDraft()

        XCTAssertEqual(draft.name, "train-resnet50")
        XCTAssertEqual(draft.hostID, hostID)
        XCTAssertEqual(draft.sessionID, sessionID)
        XCTAssertEqual(draft.command, "python train.py")
        XCTAssertEqual(draft.workingDirectory, "~/project")
    }

    func testJobDraftAvailableSessionsFiltersByHost() {
        let selectedHostID = UUID()
        let matchingSession = TmuxSession(
            id: UUID(),
            hostID: selectedHostID,
            hostName: "gpu-01",
            name: "vision-lab",
            workingDirectory: nil,
            status: .attached,
            createdAt: Date(timeIntervalSince1970: 10),
            lastAttachedAt: nil
        )
        let otherSession = TmuxSession(
            id: UUID(),
            hostID: UUID(),
            hostName: "sim-lab",
            name: "case7",
            workingDirectory: nil,
            status: .detached,
            createdAt: Date(timeIntervalSince1970: 20),
            lastAttachedAt: nil
        )
        let draft = JobDraft(hostID: selectedHostID)

        XCTAssertEqual(draft.availableSessions(in: [matchingSession, otherSession]), [matchingSession])
    }

    func testJobDraftSessionHelpersNormalizeAgainstCurrentSessions() {
        let hostID = UUID()
        let firstSession = TmuxSession(
            id: UUID(),
            hostID: hostID,
            hostName: "gpu-01",
            name: "vision-lab",
            workingDirectory: nil,
            status: .attached,
            createdAt: Date(timeIntervalSince1970: 10),
            lastAttachedAt: nil
        )
        let secondSession = TmuxSession(
            id: UUID(),
            hostID: UUID(),
            hostName: "sim-lab",
            name: "case7",
            workingDirectory: nil,
            status: .detached,
            createdAt: Date(timeIntervalSince1970: 20),
            lastAttachedAt: nil
        )

        XCTAssertNil(JobDraft().normalizedSessionID(in: []))
        XCTAssertEqual(JobDraft(sessionID: firstSession.id).normalizedSessionID(in: [firstSession]), firstSession.id)
        XCTAssertEqual(JobDraft(hostID: hostID).normalizedSessionID(in: [firstSession, secondSession]), firstSession.id)
        XCTAssertEqual(JobDraft().normalizedSessionID(in: [firstSession, secondSession]), firstSession.id)

        let staleDraft = JobDraft(sessionID: UUID())
        XCTAssertEqual(staleDraft.normalizedSessionID(in: [firstSession]), staleDraft.sessionID)
        XCTAssertTrue(JobDraft(sessionID: firstSession.id).selectedSessionExists(in: [firstSession]))
        XCTAssertFalse(staleDraft.selectedSessionExists(in: [firstSession]))
        XCTAssertFalse(JobDraft().selectedSessionExists(in: [firstSession]))
    }

    func testJobInitializerUsesDefaultSessionFieldsAndHelpers() {
        let host = Host(
            id: UUID(),
            name: "gpu-01",
            hostAlias: "gpu-01",
            username: nil,
            port: nil,
            status: .unknown,
            statusMessage: nil,
            lastCheckedAt: nil
        )
        let job = Job(
            id: UUID(),
            name: "train-resnet50",
            hostID: host.id,
            hostName: host.name,
            status: .queued,
            progressSummary: "Queued",
            startedAt: Date(timeIntervalSince1970: 100),
            command: "python train.py",
            workingDirectory: nil,
            pid: nil
        )

        XCTAssertEqual(job.sessionID, host.id)
        XCTAssertEqual(job.sessionName, "default")
        XCTAssertTrue(job.isHostAvailable(in: [host]))
        XCTAssertTrue(job.isSessionAvailable(in: [
            TmuxSession(
                id: host.id,
                hostID: host.id,
                hostName: host.name,
                name: "default",
                workingDirectory: nil,
                status: .attached,
                createdAt: Date(timeIntervalSince1970: 0),
                lastAttachedAt: nil
            )
        ]))
        XCTAssertNil(job.executionSummary)
        XCTAssertTrue(job.runtimeSummary.hasPrefix("Started: "))
    }

    func testJobIsHostAvailableMatchesByIdentifier() {
        let host = Host(
            id: UUID(),
            name: "gpu-01",
            hostAlias: "gpu-01",
            username: nil,
            port: nil,
            status: .unknown,
            statusMessage: nil,
            lastCheckedAt: nil
        )
        let job = Job(
            id: UUID(),
            name: "train-resnet50",
            hostID: host.id,
            hostName: host.name,
            status: .running,
            progressSummary: "Epoch 2/10",
            startedAt: Date(timeIntervalSince1970: 100),
            command: "python train.py",
            workingDirectory: nil,
            pid: 12345
        )
        let orphanedJob = Job(
            id: UUID(),
            name: "train-resnet50",
            hostID: UUID(),
            hostName: "removed-host",
            status: .running,
            progressSummary: "Epoch 2/10",
            startedAt: Date(timeIntervalSince1970: 100),
            command: "python train.py",
            workingDirectory: nil,
            pid: 12345
        )

        XCTAssertTrue(job.isHostAvailable(in: [host]))
        XCTAssertFalse(orphanedJob.isHostAvailable(in: [host]))
    }

    func testJobIsSessionAvailableMatchesByIdentifier() {
        let session = TmuxSession(
            id: UUID(),
            hostID: UUID(),
            hostName: "gpu-01",
            name: "vision-lab",
            workingDirectory: nil,
            status: .attached,
            createdAt: Date(timeIntervalSince1970: 0),
            lastAttachedAt: nil
        )
        let job = Job(
            id: UUID(),
            name: "train-resnet50",
            hostID: session.hostID,
            hostName: session.hostName,
            sessionID: session.id,
            sessionName: session.name,
            status: .running,
            progressSummary: "Epoch 2/10",
            startedAt: Date(timeIntervalSince1970: 100),
            command: "python train.py",
            workingDirectory: nil,
            pid: 12345
        )

        XCTAssertTrue(job.isSessionAvailable(in: [session]))
        XCTAssertFalse(job.isSessionAvailable(in: []))
        XCTAssertEqual(job.executionSummary, "PID 12345")
    }
}
