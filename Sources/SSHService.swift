import Foundation

struct SSHService {
    func runConnectivityCheck(for host: Host) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            var arguments = [
                "ssh",
                "-o",
                "BatchMode=yes",
                "-o",
                "ConnectTimeout=5"
            ]

            if let port = host.port {
                arguments.append(contentsOf: ["-p", String(port)])
            }

            if let username = host.username, !username.isEmpty {
                arguments.append(contentsOf: ["-l", username])
            }

            arguments.append(contentsOf: [host.hostAlias, "echo", "ok"])
            process.arguments = arguments

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            process.terminationHandler = { process in
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)

                guard process.terminationStatus == 0 else {
                    continuation.resume(throwing: SSHServiceError.connectivityCheckFailed(output.isEmpty ? "ssh failed" : output))
                    return
                }

                continuation.resume(returning: output.isEmpty ? "Connection OK" : output)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
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
