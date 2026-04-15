import Foundation

struct SSHService {
    func runConnectivityCheck(for host: Host) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["ssh", "-o", "BatchMode=yes", host.hostAlias, "echo", "ok"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)

        guard process.terminationStatus == 0 else {
            throw SSHServiceError.connectivityCheckFailed(output.isEmpty ? "ssh failed" : output)
        }

        return output
    }
}

enum SSHServiceError: LocalizedError {
    case connectivityCheckFailed(String)

    var errorDescription: String? {
        switch self {
        case .connectivityCheckFailed(let message):
            return message
        }
    }
}
