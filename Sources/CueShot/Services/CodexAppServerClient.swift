import Foundation

struct CodexAppServerClient {
    struct CLIResolution: Equatable {
        let executablePath: String?
        let checkedPaths: [String]
        let overridePath: String?

        var isAvailable: Bool { executablePath != nil }

        var commandDescription: String {
            guard let executablePath else {
                return "codex app-server --listen stdio:// (unresolved)"
            }
            return "\(executablePath) app-server --listen stdio://"
        }

        var displayDescription: String {
            if let executablePath {
                return executablePath
            }
            return "Not found. Checked \(checkedPaths.joined(separator: ", "))"
        }
    }

    struct AppServerDiagnostics: Equatable {
        var command: String
        var launchSucceeded: Bool = false
        var initializeRequest: String?
        var initializeResponse: String?
        var threadRequest: String?
        var threadResponse: String?
        var turnRequest: String?
        var turnResponse: String?
        var stderrTail: String = ""

        static func unresolvedCLI(_ resolution: CLIResolution) -> AppServerDiagnostics {
            AppServerDiagnostics(
                command: resolution.commandDescription,
                launchSucceeded: false,
                stderrTail: "Codex CLI was not found. \(resolution.displayDescription)"
            )
        }

        var summary: String {
            let stderr = stderrTail.trimmingCharacters(in: .whitespacesAndNewlines)
            return [
                "command: \(command)",
                "launch: \(launchSucceeded ? "ok" : "failed")",
                "initialize request: \(Self.snippet(initializeRequest))",
                "initialize response: \(Self.snippet(initializeResponse))",
                "thread request: \(Self.snippet(threadRequest))",
                "thread response: \(Self.snippet(threadResponse))",
                "turn request: \(Self.snippet(turnRequest))",
                "turn response: \(Self.snippet(turnResponse))",
                "stderr tail: \(stderr.isEmpty ? "<empty>" : Self.snippet(stderr))"
            ].joined(separator: "\n")
        }

        private static func snippet(_ value: String?) -> String {
            guard let value, !value.isEmpty else { return "<none>" }
            let compact = value.replacingOccurrences(of: "\n", with: "\\n")
            guard compact.count > 900 else { return compact }
            return "\(compact.prefix(900))..."
        }
    }

    struct SendResult: Equatable {
        let threadID: String
        let turnID: String?
        let detail: String
        let diagnostics: AppServerDiagnostics
    }

    enum SendError: LocalizedError, Equatable {
        case fileMissing(String, AppServerDiagnostics)
        case launchFailed(String, AppServerDiagnostics)
        case timeout(String, AppServerDiagnostics)
        case protocolError(String, AppServerDiagnostics)
        case serverError(String, AppServerDiagnostics)

        var errorDescription: String? {
            switch self {
            case .fileMissing(let path, _):
                "Capture file does not exist: \(path)"
            case .launchFailed(let detail, _):
                "Could not start Codex App Server: \(detail)"
            case .timeout(let detail, _):
                "Codex App Server timed out: \(detail)"
            case .protocolError(let detail, _):
                "Codex App Server protocol error: \(detail)"
            case .serverError(let detail, _):
                "Codex App Server returned an error: \(detail)"
            }
        }

        var diagnostics: AppServerDiagnostics {
            switch self {
            case .fileMissing(_, let diagnostics),
                 .launchFailed(_, let diagnostics),
                 .timeout(_, let diagnostics),
                 .protocolError(_, let diagnostics),
                 .serverError(_, let diagnostics):
                diagnostics
            }
        }
    }

    static let commonCLIPaths: [String] = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "\(home)/.local/bin/codex"
        ]
    }()

    static func resolveCLIPath(override: String? = nil) -> CLIResolution {
        let trimmedOverride = override?.trimmingCharacters(in: .whitespacesAndNewlines)
        let overridePath = trimmedOverride?.isEmpty == false ? expandTilde(trimmedOverride!) : nil
        var checked: [String] = []

        if let overridePath {
            checked.append(overridePath)
            if FileManager.default.isExecutableFile(atPath: overridePath) {
                return CLIResolution(executablePath: overridePath, checkedPaths: checked, overridePath: overridePath)
            }
        }

        for path in commonCLIPaths {
            checked.append(path)
            if FileManager.default.isExecutableFile(atPath: path) {
                return CLIResolution(executablePath: path, checkedPaths: checked, overridePath: overridePath)
            }
        }

        let pathDirectories = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
        for directory in pathDirectories {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent("codex").path
            guard !checked.contains(candidate) else { continue }
            checked.append(candidate)
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return CLIResolution(executablePath: candidate, checkedPaths: checked, overridePath: overridePath)
            }
        }

        return CLIResolution(executablePath: nil, checkedPaths: checked, overridePath: overridePath)
    }

    static func makeInitializeParams(version: String) -> [String: Any] {
        [
            "clientInfo": [
                "name": "cueshot",
                "title": "CueShot",
                "version": version
            ],
            "capabilities": [
                "experimentalApi": false,
                "requestAttestation": false,
                "optOutNotificationMethods": NSNull()
            ]
        ]
    }

    static func makeTurnStartParams(threadID: String, prompt: String, imagePath: String) -> [String: Any] {
        [
            "threadId": threadID,
            "input": [
                [
                    "type": "text",
                    "text": prompt,
                    "text_elements": []
                ],
                [
                    "type": "localImage",
                    "path": imagePath
                ]
            ]
        ]
    }

    func sendLocalImage(fileURL: URL, prompt: String, cliPathOverride: String? = nil) async -> Result<SendResult, SendError> {
        let path = fileURL.path
        let resolution = Self.resolveCLIPath(override: cliPathOverride)
        var diagnostics = AppServerDiagnostics(command: resolution.commandDescription)

        guard FileManager.default.fileExists(atPath: path) else {
            return .failure(.fileMissing(path, diagnostics))
        }

        guard let executablePath = resolution.executablePath else {
            diagnostics = .unresolvedCLI(resolution)
            return .failure(.launchFailed("Codex CLI executable was not found.", diagnostics))
        }

        return await Task.detached(priority: .userInitiated) {
            var diagnostics = AppServerDiagnostics(command: "\(executablePath) app-server --listen stdio://")
            do {
                let session = CodexAppServerSession(executablePath: executablePath)
                try session.start()
                diagnostics.launchSucceeded = true
                defer { session.stop() }

                let initialize = try session.request(
                    method: "initialize",
                    params: Self.makeInitializeParams(
                        version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
                    ),
                    timeout: 8
                )
                diagnostics.initializeRequest = initialize.requestLine
                diagnostics.initializeResponse = initialize.responseLine
                try session.notify(method: "initialized")

                let threadResponse = try session.request(
                    method: "thread/start",
                    params: [:],
                    timeout: 15
                )
                diagnostics.threadRequest = threadResponse.requestLine
                diagnostics.threadResponse = threadResponse.responseLine
                let thread = try Self.dictionary(threadResponse.response, keyPath: ["result", "thread"])
                let threadID = try Self.string(thread, key: "id")

                let turnResponse = try session.request(
                    method: "turn/start",
                    params: Self.makeTurnStartParams(threadID: threadID, prompt: prompt, imagePath: path),
                    timeout: 15
                )
                diagnostics.turnRequest = turnResponse.requestLine
                diagnostics.turnResponse = turnResponse.responseLine
                diagnostics.stderrTail = session.stderrTail()
                let turn = (try? Self.dictionary(turnResponse.response, keyPath: ["result", "turn"])) ?? [:]
                let turnID = turn["id"] as? String

                return .success(SendResult(
                    threadID: threadID,
                    turnID: turnID,
                    detail: "Codex App Server accepted local image \(path).",
                    diagnostics: diagnostics
                ))
            } catch let error as CodexAppServerSession.SessionFailure {
                diagnostics.stderrTail = error.stderrTail.isEmpty ? diagnostics.stderrTail : error.stderrTail
                switch error {
                case .launchFailed(let detail, _):
                    return .failure(.launchFailed(detail, diagnostics))
                case .timeout(let detail, _):
                    return .failure(.timeout(detail, diagnostics))
                case .protocolError(let detail, _):
                    return .failure(.protocolError(detail, diagnostics))
                case .serverError(let detail, _):
                    return .failure(.serverError(detail, diagnostics))
                }
            } catch {
                return .failure(.protocolError(error.localizedDescription, diagnostics))
            }
        }.value
    }

    private static func dictionary(_ dictionary: [String: Any], keyPath: [String]) throws -> [String: Any] {
        var current: Any = dictionary
        for key in keyPath {
            guard let object = current as? [String: Any], let next = object[key] else {
                throw CodexAppServerSession.SessionFailure.protocolError("Missing key path: \(keyPath.joined(separator: "."))", "")
            }
            current = next
        }
        guard let result = current as? [String: Any] else {
            throw CodexAppServerSession.SessionFailure.protocolError("Expected object at key path: \(keyPath.joined(separator: "."))", "")
        }
        return result
    }

    private static func string(_ dictionary: [String: Any], key: String) throws -> String {
        guard let value = dictionary[key] as? String, !value.isEmpty else {
            throw CodexAppServerSession.SessionFailure.protocolError("Missing string key: \(key)", "")
        }
        return value
    }

    private static func expandTilde(_ path: String) -> String {
        guard path == "~" || path.hasPrefix("~/") else { return path }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path == "~" {
            return home
        }
        return home + path.dropFirst()
    }
}

private final class CodexAppServerSession: @unchecked Sendable {
    enum SessionFailure: LocalizedError {
        case launchFailed(String, String)
        case timeout(String, String)
        case protocolError(String, String)
        case serverError(String, String)

        var stderrTail: String {
            switch self {
            case .launchFailed(_, let stderr),
                 .timeout(_, let stderr),
                 .protocolError(_, let stderr),
                 .serverError(_, let stderr):
                stderr
            }
        }
    }

    struct RPCExchange {
        let requestLine: String
        let response: [String: Any]
        let responseLine: String
    }

    private struct RPCMessage {
        let line: String
        let object: [String: Any]
    }

    private let executablePath: String
    private let process = Process()
    private let stdinPipe = Pipe()
    private let stdoutPipe = Pipe()
    private let stderrPipe = Pipe()
    private let condition = NSCondition()
    private var nextID = 1
    private var buffer = Data()
    private var messages: [RPCMessage] = []
    private var stderrData = Data()
    private var isStarted = false

    init(executablePath: String) {
        self.executablePath = executablePath
    }

    func start() throws {
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = ["app-server", "--listen", "stdio://"]
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.environment = environmentWithCommonDeveloperPath()

        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.appendStdout(data)
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.appendStderr(data)
        }

        do {
            try process.run()
            isStarted = true
        } catch {
            throw SessionFailure.launchFailed(error.localizedDescription, stderrTail())
        }
    }

    func stop() {
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        if isStarted, process.isRunning {
            process.terminate()
        }
        try? stdinPipe.fileHandleForWriting.close()
    }

    func request(method: String, params: [String: Any], timeout: TimeInterval) throws -> RPCExchange {
        let id = nextID
        nextID += 1
        let requestLine = try send(["method": method, "id": id, "params": params])
        let response = try waitForResponse(id: id, method: method, timeout: timeout)
        return RPCExchange(requestLine: requestLine, response: response.object, responseLine: response.line)
    }

    func notify(method: String) throws {
        _ = try send(["method": method])
    }

    private func send(_ message: [String: Any]) throws -> String {
        guard JSONSerialization.isValidJSONObject(message) else {
            throw SessionFailure.protocolError("Invalid JSON request.", stderrTail())
        }
        let data = try JSONSerialization.data(withJSONObject: message, options: [])
        stdinPipe.fileHandleForWriting.write(data)
        stdinPipe.fileHandleForWriting.write(Data([0x0A]))
        return String(data: data, encoding: .utf8) ?? String(describing: message)
    }

    private func waitForResponse(id: Int, method: String, timeout: TimeInterval) throws -> RPCMessage {
        let deadline = Date().addingTimeInterval(timeout)
        condition.lock()
        defer { condition.unlock() }

        while true {
            if let index = messages.firstIndex(where: { ($0.object["id"] as? Int) == id }) {
                let response = messages.remove(at: index)
                if let error = response.object["error"] as? [String: Any] {
                    let message = error["message"] as? String ?? String(describing: error)
                    throw SessionFailure.serverError("\(method): \(message)", stderrText())
                }
                return response
            }

            if Date() >= deadline {
                let stderr = stderrText()
                let suffix = stderr.isEmpty ? "" : " Stderr: \(stderr)"
                throw SessionFailure.timeout("No response for \(method).\(suffix)", stderr)
            }

            condition.wait(until: min(deadline, Date().addingTimeInterval(0.25)))
        }
    }

    private func appendStdout(_ data: Data) {
        condition.lock()
        buffer.append(data)

        while let newlineRange = buffer.firstRange(of: Data([0x0A])) {
            let line = buffer.subdata(in: buffer.startIndex..<newlineRange.lowerBound)
            buffer.removeSubrange(buffer.startIndex..<newlineRange.upperBound)
            guard !line.isEmpty,
                  let message = try? JSONSerialization.jsonObject(with: line) as? [String: Any]
            else {
                continue
            }
            let lineText = String(data: line, encoding: .utf8) ?? ""
            messages.append(RPCMessage(line: lineText, object: message))
        }

        condition.broadcast()
        condition.unlock()
    }

    private func appendStderr(_ data: Data) {
        condition.lock()
        stderrData.append(data)
        condition.broadcast()
        condition.unlock()
    }

    func stderrTail() -> String {
        condition.lock()
        defer { condition.unlock() }
        return stderrText()
    }

    private func stderrText() -> String {
        String(data: stderrData.suffix(4096), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func environmentWithCommonDeveloperPath() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let commonPath = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "\(home)/.local/bin",
            "\(home)/.cargo/bin",
            "\(home)/.npm-global/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ].joined(separator: ":")

        let existingPath = environment["PATH"] ?? ""
        environment["PATH"] = existingPath.isEmpty ? commonPath : "\(commonPath):\(existingPath)"
        return environment
    }
}
