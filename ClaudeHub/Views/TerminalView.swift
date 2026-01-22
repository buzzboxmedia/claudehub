import SwiftUI
import AppKit
import os.log

private let viewLogger = Logger(subsystem: "com.buzzbox.claudehub", category: "TerminalView")

// MARK: - Terminal Launcher
// Opens Claude in Terminal.app instead of embedding

class TerminalLauncher {
    static let shared = TerminalLauncher()
    private let logger = Logger(subsystem: "com.buzzbox.claudehub", category: "TerminalLauncher")

    /// Launch Claude in Terminal.app for a session
    func launchClaude(for session: Session, appState: AppState) {
        let projectPath = session.projectPath

        // Build the claude command
        var claudeCommand = "cd '\(projectPath)' && claude --dangerously-skip-permissions"

        // Resume existing session if we have a session ID
        if let claudeSessionId = session.claudeSessionId {
            claudeCommand = "cd '\(projectPath)' && claude --dangerously-skip-permissions --resume '\(claudeSessionId)'"
        }

        logger.info("Launching Terminal.app with: \(claudeCommand)")

        // AppleScript to open Terminal.app and run the command
        let script = """
        tell application "Terminal"
            activate
            do script "\(claudeCommand)"
        end tell
        """

        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
            if let error = error {
                logger.error("AppleScript error: \(error)")
            } else {
                logger.info("Terminal.app launched successfully")
                // Mark session as active
                session.lastAccessedAt = Date()
                // Start monitoring for session ID if we don't have one
                if session.claudeSessionId == nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        self.captureClaudeSessionId(for: session)
                    }
                }
            }
        }
    }

    /// Capture the Claude session ID from disk
    func captureClaudeSessionId(for session: Session) {
        let claudeProjectPath = session.projectPath.replacingOccurrences(of: "/", with: "-")
        let claudeProjectsDir = "\(NSHomeDirectory())/.claude/projects/\(claudeProjectPath)"

        logger.info("Looking for Claude session in: \(claudeProjectsDir)")

        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(atPath: claudeProjectsDir) else {
            logger.warning("Could not read Claude projects directory")
            return
        }

        // Find the most recently modified .jsonl file
        var latestFile: (name: String, date: Date)?
        for file in files where file.hasSuffix(".jsonl") {
            let filePath = "\(claudeProjectsDir)/\(file)"
            if let attrs = try? fileManager.attributesOfItem(atPath: filePath),
               let modDate = attrs[.modificationDate] as? Date {
                if latestFile == nil || modDate > latestFile!.date {
                    latestFile = (file, modDate)
                }
            }
        }

        if let latest = latestFile {
            let sessionId = String(latest.name.dropLast(6))  // Remove ".jsonl"
            logger.info("Captured Claude session ID: \(sessionId)")
            session.claudeSessionId = sessionId
        }
    }

    /// Read session content from Claude's session file
    func getSessionContent(for session: Session) -> String {
        guard let claudeSessionId = session.claudeSessionId else {
            return ""
        }

        let claudeProjectPath = session.projectPath.replacingOccurrences(of: "/", with: "-")
        let sessionFile = "\(NSHomeDirectory())/.claude/projects/\(claudeProjectPath)/\(claudeSessionId).jsonl"

        guard let content = try? String(contentsOfFile: sessionFile, encoding: .utf8) else {
            return ""
        }

        // Parse JSONL and extract recent messages
        let lines = content.components(separatedBy: "\n").suffix(50)
        var messages: [String] = []

        for line in lines where !line.isEmpty {
            if let data = line.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Extract message content
                if let message = json["message"] as? [String: Any],
                   let role = message["role"] as? String,
                   let contentArray = message["content"] as? [[String: Any]] {
                    for contentItem in contentArray {
                        if let text = contentItem["text"] as? String {
                            let prefix = role == "user" ? "You: " : "Claude: "
                            let truncated = String(text.prefix(300))
                            messages.append(prefix + truncated)
                        }
                    }
                }
            }
        }

        return messages.suffix(10).joined(separator: "\n\n")
    }
}

// MARK: - Session Info View
// Shows recent session activity (Terminal.app auto-launches on session/project click)

struct TerminalView: View {
    let session: Session
    @EnvironmentObject var appState: AppState
    @State private var sessionContent: String = ""
    @State private var refreshTimer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            // Session content area - shows recent activity from Claude session file
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Recent activity from Claude session file
                    if !sessionContent.isEmpty {
                        recentActivitySection
                    } else {
                        emptyStateView
                    }
                }
                .padding(20)
            }
        }
        .background(Color(NSColor(calibratedRed: 0.075, green: 0.082, blue: 0.11, alpha: 1.0)))
        .onAppear {
            loadSessionContent()
            startRefreshTimer()
        }
        .onDisappear {
            refreshTimer?.invalidate()
        }
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent Activity")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(red: 0.6, green: 0.65, blue: 0.75))

                Spacer()

                if let claudeSessionId = session.claudeSessionId {
                    Text("Session: \(claudeSessionId.prefix(8))...")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(red: 0.4, green: 0.5, blue: 0.6))
                }
            }

            ScrollView {
                Text(sessionContent)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color(red: 0.8, green: 0.83, blue: 0.9))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(Color.black.opacity(0.3))
            .cornerRadius(8)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundColor(Color(red: 0.3, green: 0.4, blue: 0.5))

            Text("Session running in Terminal.app")
                .font(.system(size: 14))
                .foregroundColor(Color(red: 0.5, green: 0.55, blue: 0.65))

            Text("Activity will appear here once Claude starts")
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0.4, green: 0.45, blue: 0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func loadSessionContent() {
        sessionContent = TerminalLauncher.shared.getSessionContent(for: session)
    }

    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            loadSessionContent()
        }
    }
}

// MARK: - Preview

#Preview {
    TerminalView(session: Session(name: "Test Session", projectPath: "/Users/test/project"))
        .environmentObject(AppState())
        .frame(width: 600, height: 400)
}
