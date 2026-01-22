import Foundation
import Network
import os.log

private let serverLogger = Logger(subsystem: "com.buzzbox.claudehub", category: "TailscaleServer")

/// Simple HTTP server for iOS companion app via Tailscale
class TailscaleServer {
    static let shared = TailscaleServer()

    private var listener: NWListener?
    private let port: UInt16 = 8847  // CHUB on phone keypad
    private let queue = DispatchQueue(label: "com.buzzbox.claudehub.server")

    // References needed for handling requests
    weak var appState: AppState?

    var isRunning: Bool {
        listener?.state == .ready
    }

    var serverURL: String? {
        guard isRunning else { return nil }
        if let tailscaleIP = getTailscaleIP() {
            return "http://\(tailscaleIP):\(port)"
        }
        return "http://localhost:\(port)"
    }

    func start(appState: AppState) {
        self.appState = appState

        do {
            // Simple TCP listener - NWListener should bind to all interfaces by default
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true

            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
            serverLogger.info("Created listener on port \(self.port)")

            listener?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    if let port = self?.listener?.port {
                        serverLogger.info("Server ready on port \(port.rawValue)")
                    }
                    if let ip = self?.getTailscaleIP() {
                        serverLogger.info("Tailscale URL: http://\(ip):\(self?.port ?? 0)")
                    }
                    // Log what we're actually listening on
                    serverLogger.info("Listener parameters: \(String(describing: self?.listener?.parameters))")
                case .failed(let error):
                    serverLogger.error("Server failed: \(error.localizedDescription)")
                case .cancelled:
                    serverLogger.info("Server cancelled")
                default:
                    break
                }
            }

            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            listener?.start(queue: queue)
            serverLogger.info("Starting Tailscale server...")

        } catch {
            serverLogger.error("Failed to create listener: \(error.localizedDescription)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        serverLogger.info("Server stopped")
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                self.receiveRequest(connection)
            case .failed(let error):
                serverLogger.error("Connection failed: \(error.localizedDescription)")
                connection.cancel()
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    private func receiveRequest(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.processRequest(data, connection: connection)
            }
            if isComplete || error != nil {
                connection.cancel()
            }
        }
    }

    private func processRequest(_ data: Data, connection: NWConnection) {
        guard let request = String(data: data, encoding: .utf8) else {
            sendResponse(connection, status: 400, body: ["error": "Invalid request"])
            return
        }

        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            sendResponse(connection, status: 400, body: ["error": "Empty request"])
            return
        }

        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            sendResponse(connection, status: 400, body: ["error": "Malformed request"])
            return
        }

        let method = parts[0]
        let path = parts[1]

        // Extract body for POST requests
        var body: [String: Any]?
        if method == "POST", let bodyStart = request.range(of: "\r\n\r\n") {
            let bodyString = String(request[bodyStart.upperBound...])
            if let bodyData = bodyString.data(using: .utf8) {
                body = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
            }
        }

        serverLogger.info("Request: \(method) \(path)")

        // Route the request
        route(method: method, path: path, body: body, connection: connection)
    }

    // MARK: - Routing

    private func route(method: String, path: String, body: [String: Any]?, connection: NWConnection) {
        // CORS preflight
        if method == "OPTIONS" {
            sendResponse(connection, status: 200, body: ["ok": true])
            return
        }

        switch (method, path) {
        case ("GET", "/api/status"):
            handleStatus(connection)

        case ("GET", "/api/sessions"):
            handleGetSessions(connection)

        case ("GET", let p) where p.hasPrefix("/api/sessions/") && p.hasSuffix("/terminal"):
            let sessionId = extractSessionId(from: p, suffix: "/terminal")
            handleGetTerminal(sessionId: sessionId, connection: connection)

        case ("POST", let p) where p.hasPrefix("/api/sessions/") && p.hasSuffix("/reply"):
            let sessionId = extractSessionId(from: p, suffix: "/reply")
            handleReply(sessionId: sessionId, body: body, connection: connection)

        case ("POST", let p) where p.hasPrefix("/api/sessions/") && p.hasSuffix("/complete"):
            let sessionId = extractSessionId(from: p, suffix: "/complete")
            handleComplete(sessionId: sessionId, connection: connection)

        default:
            sendResponse(connection, status: 404, body: ["error": "Not found", "path": path])
        }
    }

    private func extractSessionId(from path: String, suffix: String) -> String? {
        let withoutPrefix = path.dropFirst("/api/sessions/".count)
        let withoutSuffix = withoutPrefix.dropLast(suffix.count)
        return String(withoutSuffix)
    }

    // MARK: - Handlers

    private func handleStatus(_ connection: NWConnection) {
        let waitingCount = appState?.waitingSessions.count ?? 0
        let launchedCount = appState?.launchedSessions.count ?? 0

        sendResponse(connection, status: 200, body: [
            "status": "ok",
            "app": "ClaudeHub",
            "version": AppVersion.version,
            "waiting_sessions": waitingCount,
            "launched_sessions": launchedCount,
            "tailscale_ip": getTailscaleIP() ?? "unknown"
        ])
    }

    private func handleGetSessions(_ connection: NWConnection) {
        guard let appState = appState else {
            sendResponse(connection, status: 500, body: ["error": "App state unavailable"])
            return
        }

        // Return launched session IDs - full session details would need SwiftData access
        let sessions = appState.launchedSessions.map { id in
            [
                "id": id.uuidString,
                "is_waiting": appState.waitingSessions.contains(id)
            ] as [String: Any]
        }

        sendResponse(connection, status: 200, body: [
            "sessions": sessions,
            "count": sessions.count
        ])
    }

    private func handleGetTerminal(sessionId: String?, connection: NWConnection) {
        // With Terminal.app approach, we can't directly access terminal content
        // Would need to read from Claude's session files
        sendResponse(connection, status: 501, body: [
            "error": "Terminal content not available - using Terminal.app for sessions"
        ])
    }

    private func handleReply(sessionId: String?, body: [String: Any]?, connection: NWConnection) {
        // With Terminal.app approach, we can't directly send to terminal
        // User needs to interact directly with Terminal.app
        sendResponse(connection, status: 501, body: [
            "error": "Direct terminal input not available - using Terminal.app for sessions"
        ])
    }

    private func handleComplete(sessionId: String?, connection: NWConnection) {
        // Can still mark sessions complete via this endpoint
        // Would need SwiftData access to update the session
        sendResponse(connection, status: 501, body: [
            "error": "Session completion via API not yet implemented for Terminal.app approach"
        ])
    }

    // MARK: - Response

    private func sendResponse(_ connection: NWConnection, status: Int, body: [String: Any]) {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 404: statusText = "Not Found"
        case 500: statusText = "Internal Server Error"
        default: statusText = "Unknown"
        }

        let jsonData = try? JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
        let jsonString = jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        let response = """
        HTTP/1.1 \(status) \(statusText)\r
        Content-Type: application/json\r
        Access-Control-Allow-Origin: *\r
        Access-Control-Allow-Methods: GET, POST, OPTIONS\r
        Access-Control-Allow-Headers: Content-Type\r
        Content-Length: \(jsonString.utf8.count)\r
        Connection: close\r
        \r
        \(jsonString)
        """

        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    // MARK: - Tailscale IP Detection

    func getTailscaleIP() -> String? {
        // Try tailscale CLI first (works with userspace networking)
        if let cliIP = getTailscaleIPFromCLI() {
            return cliIP
        }

        // Fallback to interface scan (legacy kernel networking mode)
        return getTailscaleIPFromInterfaces()
    }

    private func getTailscaleIPFromCLI() -> String? {
        let process = Process()
        let pipe = Pipe()

        // Try the CLI in common locations
        let paths = [
            "/usr/local/bin/tailscale",
            "/opt/homebrew/bin/tailscale",
            "/Applications/Tailscale.app/Contents/MacOS/Tailscale"
        ]

        var tailscalePath: String?
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                tailscalePath = path
                break
            }
        }

        guard let path = tailscalePath else {
            return nil
        }

        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["ip", "-4"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               output.hasPrefix("100.") {
                return output
            }
        } catch {
            serverLogger.debug("Failed to get IP from tailscale CLI: \(error.localizedDescription)")
        }

        return nil
    }

    private func getTailscaleIPFromInterfaces() -> String? {
        var addresses: [String] = []

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }
        defer { freeifaddrs(ifaddr) }

        var ptr = firstAddr
        while true {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family

            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)

                // Tailscale interface is typically utun* on macOS
                if name.hasPrefix("utun") {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                   &hostname, socklen_t(hostname.count),
                                   nil, 0, NI_NUMERICHOST) == 0 {
                        let address = String(cString: hostname)
                        // Tailscale IPs are in 100.x.x.x range
                        if address.hasPrefix("100.") {
                            return address
                        }
                        addresses.append(address)
                    }
                }
            }

            guard let next = interface.ifa_next else { break }
            ptr = next
        }

        return addresses.first
    }
}
