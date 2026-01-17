import Foundation
import CloudKit

/// Service for communicating with Mac via Tailscale
actor QuickReplyService {
    static let shared = QuickReplyService()

    // Tailscale server settings
    private let port: Int = 8847
    private var macIP: String {
        UserDefaults.standard.string(forKey: "mac_tailscale_ip") ?? ""
    }

    private var baseURL: String {
        "http://\(macIP):\(port)"
    }

    // MARK: - API Methods

    /// Send a quick reply to a session
    func send(reply: String, to session: Session) async throws {
        guard !macIP.isEmpty else {
            throw ServerError.notConfigured
        }

        let url = URL(string: "\(baseURL)/api/sessions/\(session.id.uuidString)/reply")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body = ["message": reply]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let errorBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            throw ServerError.requestFailed(errorBody?["error"] as? String ?? "Unknown error")
        }
    }

    /// Get server status
    func getStatus() async throws -> ServerStatus {
        guard !macIP.isEmpty else {
            throw ServerError.notConfigured
        }

        let url = URL(string: "\(baseURL)/api/status")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ServerError.requestFailed("Server not responding")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        return ServerStatus(
            isOnline: true,
            version: json?["version"] as? String ?? "unknown",
            waitingSessions: json?["waiting_sessions"] as? Int ?? 0,
            activeSessions: json?["active_sessions"] as? Int ?? 0
        )
    }

    /// Get active sessions from Mac
    func getSessions() async throws -> [[String: Any]] {
        guard !macIP.isEmpty else {
            throw ServerError.notConfigured
        }

        let url = URL(string: "\(baseURL)/api/sessions")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ServerError.requestFailed("Failed to fetch sessions")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["sessions"] as? [[String: Any]] ?? []
    }

    /// Get terminal content for a session
    func getTerminalContent(sessionId: UUID) async throws -> String {
        guard !macIP.isEmpty else {
            throw ServerError.notConfigured
        }

        let url = URL(string: "\(baseURL)/api/sessions/\(sessionId.uuidString)/terminal")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ServerError.requestFailed("Failed to fetch terminal")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["content"] as? String ?? ""
    }

    /// Mark a session as complete
    func completeSession(_ session: Session) async throws {
        guard !macIP.isEmpty else {
            throw ServerError.notConfigured
        }

        let url = URL(string: "\(baseURL)/api/sessions/\(session.id.uuidString)/complete")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ServerError.requestFailed("Failed to complete session")
        }
    }

    // MARK: - Configuration

    func setMacIP(_ ip: String) {
        UserDefaults.standard.set(ip, forKey: "mac_tailscale_ip")
    }

    func getMacIP() -> String {
        macIP
    }

    // MARK: - CloudKit Fallback (for when not on Tailscale)

    private let cloudKitContainer = CKContainer(identifier: "iCloud.com.buzzbox.claudehub")

    func sendViaCloudKit(reply: String, to session: Session) async throws {
        let record = CKRecord(recordType: "QuickReply")
        record["sessionId"] = session.id.uuidString
        record["sessionName"] = session.name
        record["message"] = reply
        record["timestamp"] = Date()
        record["processed"] = false

        try await cloudKitContainer.privateCloudDatabase.save(record)
    }

    func checkCloudKitStatus() async throws -> CKAccountStatus {
        try await cloudKitContainer.accountStatus()
    }
}

// MARK: - Types

struct ServerStatus {
    let isOnline: Bool
    let version: String
    let waitingSessions: Int
    let activeSessions: Int
}

enum ServerError: LocalizedError {
    case notConfigured
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Mac IP not configured. Go to Settings to set your Tailscale IP."
        case .requestFailed(let message):
            return message
        }
    }
}

// MARK: - Connection Status View

import SwiftUI

struct ConnectionStatusView: View {
    @State private var status: ServerStatus?
    @State private var isChecking = false
    @State private var error: String?
    @State private var macIP: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Mac IP Configuration
            HStack {
                Image(systemName: "network")
                    .foregroundStyle(.blue)

                TextField("Mac Tailscale IP (e.g., 100.x.x.x)", text: $macIP)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                    .autocorrectionDisabled()

                Button("Save") {
                    Task {
                        await QuickReplyService.shared.setMacIP(macIP)
                        await checkStatus()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(macIP.isEmpty)
            }

            Divider()

            // Connection Status
            HStack {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Mac Connection")
                        .font(.subheadline)

                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isChecking {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button("Test") {
                        Task { await checkStatus() }
                    }
                    .font(.caption)
                }
            }

            // Stats when connected
            if let status = status, status.isOnline {
                HStack(spacing: 20) {
                    Label("\(status.activeSessions) active", systemImage: "terminal")
                    Label("\(status.waitingSessions) waiting", systemImage: "bell.badge")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            Task {
                macIP = await QuickReplyService.shared.getMacIP()
                if !macIP.isEmpty {
                    await checkStatus()
                }
            }
        }
    }

    var statusIcon: String {
        if isChecking { return "arrow.triangle.2.circlepath" }
        if let error = error { return "exclamationmark.triangle" }
        if status?.isOnline == true { return "checkmark.circle" }
        return "circle.dashed"
    }

    var statusColor: Color {
        if let _ = error { return .red }
        if status?.isOnline == true { return .green }
        return .gray
    }

    var statusText: String {
        if isChecking { return "Connecting..." }
        if let error = error { return error }
        if let status = status, status.isOnline {
            return "Connected (v\(status.version))"
        }
        if macIP.isEmpty { return "Enter Mac Tailscale IP" }
        return "Not connected"
    }

    func checkStatus() async {
        isChecking = true
        error = nil

        do {
            status = try await QuickReplyService.shared.getStatus()
        } catch {
            self.error = error.localizedDescription
            self.status = nil
        }

        isChecking = false
    }
}

#Preview {
    ConnectionStatusView()
        .padding()
}
