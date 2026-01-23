import Foundation
import SwiftData
import os.log

private let syncLogger = Logger(subsystem: "com.buzzbox.claudehub", category: "SessionSync")

/// Service for syncing sessions to/from Dropbox
class SessionSyncService {
    static let shared = SessionSyncService()

    /// Feature flag - sync is disabled by default for safety
    var isEnabled: Bool = false

    /// Centralized sessions directory in Dropbox (syncs across machines)
    static var centralSessionsDir: URL {
        let path = NSString("~/Library/CloudStorage/Dropbox/Buzzbox/ClaudeHub/sessions").expandingTildeInPath
        return URL(fileURLWithPath: path)
    }

    private init() {}

    // MARK: - Export (Write to Dropbox)

    /// Export a single session to Dropbox
    func exportSession(_ session: Session) {
        guard isEnabled else {
            syncLogger.debug("Sync disabled, skipping export for session: \(session.name)")
            return
        }

        let sessionsDir = Self.centralSessionsDir

        // Create sessions directory if needed
        do {
            try FileManager.default.createDirectory(at: sessionsDir, withIntermediateDirectories: true)
        } catch {
            syncLogger.error("Failed to create sessions directory: \(error.localizedDescription)")
            return
        }

        let sessionPath = sessionsDir.appendingPathComponent("\(session.id.uuidString).json")

        do {
            // Convert session to metadata
            let metadata = session.toMetadata()

            // Encode to JSON
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(metadata)

            // Write atomically
            try data.write(to: sessionPath, options: .atomic)

            syncLogger.info("Exported session '\(session.name)' to Dropbox: \(sessionPath.path)")
        } catch {
            syncLogger.error("Failed to export session '\(session.name)': \(error.localizedDescription)")
        }
    }

    /// Export all sessions to Dropbox
    func exportAllSessions(modelContext: ModelContext) {
        guard isEnabled else {
            syncLogger.debug("Sync disabled, skipping export all")
            return
        }

        // Fetch all sessions
        let descriptor = FetchDescriptor<Session>()
        guard let sessions = try? modelContext.fetch(descriptor) else {
            syncLogger.error("Failed to fetch sessions for export")
            return
        }

        syncLogger.info("Exporting \(sessions.count) sessions to Dropbox")

        for session in sessions {
            exportSession(session)
        }

        syncLogger.info("Export complete")
    }

    // MARK: - Import (Read from Dropbox)

    /// Import all sessions from Dropbox (merge with local)
    func importAllSessions(modelContext: ModelContext) {
        guard isEnabled else {
            syncLogger.debug("Sync disabled, skipping import")
            return
        }

        let sessionsDir = Self.centralSessionsDir

        // Check if sessions directory exists
        guard FileManager.default.fileExists(atPath: sessionsDir.path) else {
            syncLogger.info("Sessions directory doesn't exist yet: \(sessionsDir.path)")
            return
        }

        // Get all JSON files
        guard let files = try? FileManager.default.contentsOfDirectory(at: sessionsDir, includingPropertiesForKeys: nil) else {
            syncLogger.error("Failed to read sessions directory")
            return
        }

        let jsonFiles = files.filter { $0.pathExtension == "json" }
        syncLogger.info("Found \(jsonFiles.count) session files to import")

        var imported = 0
        var updated = 0
        var skipped = 0

        for file in jsonFiles {
            let result = importSession(from: file, modelContext: modelContext)
            switch result {
            case .imported:
                imported += 1
            case .updated:
                updated += 1
            case .skipped:
                skipped += 1
            case .failed:
                break
            }
        }

        syncLogger.info("Import complete: \(imported) imported, \(updated) updated, \(skipped) skipped")
    }

    /// Result of importing a session
    private enum ImportResult {
        case imported  // New session created
        case updated   // Existing session updated
        case skipped   // Local version newer
        case failed    // Error occurred
    }

    /// Import a single session from JSON file
    @discardableResult
    private func importSession(from file: URL, modelContext: ModelContext) -> ImportResult {
        do {
            // Read and decode JSON
            let data = try Data(contentsOf: file)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let metadata = try decoder.decode(SessionMetadata.self, from: data)

            // Check if session already exists locally
            let descriptor = FetchDescriptor<Session>(
                predicate: #Predicate { $0.id == metadata.id }
            )
            let existingSessions = try modelContext.fetch(descriptor)
            let existingSession = existingSessions.first

            if let existing = existingSession {
                // Session exists - merge based on timestamp
                return mergeSession(local: existing, remote: metadata, modelContext: modelContext)
            } else {
                // New session - create it
                let newSession = createSessionFromMetadata(metadata, modelContext: modelContext)
                modelContext.insert(newSession)
                syncLogger.info("Imported new session '\(newSession.name)' from Dropbox")
                return .imported
            }
        } catch {
            syncLogger.error("Failed to import session from \(file.lastPathComponent): \(error.localizedDescription)")
            return .failed
        }
    }

    /// Merge remote session with local (last-write-wins)
    private func mergeSession(local: Session, remote: SessionMetadata, modelContext: ModelContext) -> ImportResult {
        // Compare timestamps - last write wins
        if remote.lastAccessedAt > local.lastAccessedAt {
            // Remote is newer - update local
            local.updateFromMetadata(remote)

            // Resolve relationships
            resolveRelationships(for: local, projectId: remote.projectId, taskGroupId: remote.taskGroupId, modelContext: modelContext)

            syncLogger.info("Updated session '\(local.name)' from remote (remote newer: \(remote.lastAccessedAt) > \(local.lastAccessedAt))")
            return .updated
        } else {
            // Local is newer or equal - keep local, update remote
            syncLogger.debug("Skipped session '\(local.name)' (local newer or equal: \(local.lastAccessedAt) >= \(remote.lastAccessedAt))")
            exportSession(local)
            return .skipped
        }
    }

    /// Create a new Session from metadata
    private func createSessionFromMetadata(_ metadata: SessionMetadata, modelContext: ModelContext) -> Session {
        let session = Session(
            name: metadata.name,
            projectPath: metadata.projectPath,
            createdAt: metadata.createdAt,
            userNamed: metadata.userNamed,
            activeProjectName: metadata.activeProjectName,
            parkerBriefing: metadata.parkerBriefing
        )

        // Set remaining properties
        session.id = metadata.id
        session.sessionDescription = metadata.sessionDescription
        session.lastAccessedAt = metadata.lastAccessedAt
        session.claudeSessionId = metadata.claudeSessionId
        session.lastSessionSummary = metadata.lastSessionSummary
        session.logFilePath = metadata.logFilePath
        session.lastLogSavedAt = metadata.lastLogSavedAt
        session.lastProgressSavedAt = metadata.lastProgressSavedAt
        session.taskFolderPath = metadata.taskFolderPath
        session.isCompleted = metadata.isCompleted
        session.completedAt = metadata.completedAt
        session.isWaitingForInput = metadata.isWaitingForInput

        // Resolve relationships
        resolveRelationships(for: session, projectId: metadata.projectId, taskGroupId: metadata.taskGroupId, modelContext: modelContext)

        return session
    }

    /// Resolve Project and ProjectGroup relationships by UUID
    private func resolveRelationships(for session: Session, projectId: UUID?, taskGroupId: UUID?, modelContext: ModelContext) {
        // Resolve Project
        if let projectId = projectId {
            let projectDescriptor = FetchDescriptor<Project>(
                predicate: #Predicate { $0.id == projectId }
            )
            if let projects = try? modelContext.fetch(projectDescriptor),
               let project = projects.first {
                session.project = project
                syncLogger.debug("Resolved project relationship for session '\(session.name)'")
            } else {
                syncLogger.warning("Could not resolve project with ID \(projectId) for session '\(session.name)'")
                session.project = nil
            }
        }

        // Resolve ProjectGroup
        if let taskGroupId = taskGroupId {
            let groupDescriptor = FetchDescriptor<ProjectGroup>(
                predicate: #Predicate { $0.id == taskGroupId }
            )
            if let groups = try? modelContext.fetch(groupDescriptor),
               let group = groups.first {
                session.taskGroup = group
                syncLogger.debug("Resolved task group relationship for session '\(session.name)'")
            } else {
                syncLogger.warning("Could not resolve task group with ID \(taskGroupId) for session '\(session.name)'")
                session.taskGroup = nil
            }
        }
    }
}
