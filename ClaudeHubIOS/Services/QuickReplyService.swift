import Foundation
import CloudKit

/// Service for sending quick replies from iOS to Mac via CloudKit
actor QuickReplyService {
    static let shared = QuickReplyService()

    private let container = CKContainer(identifier: "iCloud.com.buzzbox.claudehub")

    /// Send a quick reply to a session (Mac will pick this up)
    func send(reply: String, to session: Session) async throws {
        let record = CKRecord(recordType: "QuickReply")
        record["sessionId"] = session.id.uuidString
        record["sessionName"] = session.name
        record["message"] = reply
        record["timestamp"] = Date()
        record["processed"] = false

        try await container.privateCloudDatabase.save(record)
    }

    /// Check CloudKit availability
    func checkStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }
}

// MARK: - CloudKit Status View

import SwiftUI

struct CloudKitStatusView: View {
    @State private var status: CKAccountStatus?
    @State private var isChecking = false
    @State private var error: String?

    var body: some View {
        HStack {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("iCloud Sync")
                    .font(.subheadline)

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isChecking {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .onAppear {
            checkStatus()
        }
    }

    var statusIcon: String {
        switch status {
        case .available:
            return "checkmark.icloud"
        case .noAccount:
            return "icloud.slash"
        case .restricted:
            return "lock.icloud"
        case .couldNotDetermine:
            return "exclamationmark.icloud"
        case .temporarilyUnavailable:
            return "icloud"
        case .none:
            return "icloud"
        @unknown default:
            return "questionmark.circle"
        }
    }

    var statusColor: Color {
        switch status {
        case .available:
            return .green
        case .noAccount, .restricted:
            return .red
        case .couldNotDetermine, .temporarilyUnavailable:
            return .orange
        case .none:
            return .gray
        @unknown default:
            return .gray
        }
    }

    var statusText: String {
        if let error = error {
            return error
        }

        switch status {
        case .available:
            return "Connected"
        case .noAccount:
            return "Sign in to iCloud"
        case .restricted:
            return "iCloud restricted"
        case .couldNotDetermine:
            return "Unable to determine"
        case .temporarilyUnavailable:
            return "Temporarily unavailable"
        case .none:
            return "Checking..."
        @unknown default:
            return "Unknown status"
        }
    }

    func checkStatus() {
        isChecking = true

        Task {
            do {
                let accountStatus = try await QuickReplyService.shared.checkStatus()
                await MainActor.run {
                    self.status = accountStatus
                    self.isChecking = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isChecking = false
                }
            }
        }
    }
}

#Preview {
    CloudKitStatusView()
        .padding()
}
