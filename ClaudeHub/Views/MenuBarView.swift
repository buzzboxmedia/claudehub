import SwiftUI
import SwiftData

struct MenuBarView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState

    // Fetch all sessions and projects
    @Query(sort: \Session.lastAccessedAt, order: .reverse) private var allSessions: [Session]
    @Query(sort: \Project.name) private var allProjects: [Project]

    var waitingCount: Int {
        appState.waitingSessions.count
    }

    // Active (non-completed) sessions
    var activeSessions: [Session] {
        allSessions.filter { !$0.isCompleted }
    }

    /// Sessions sorted with waiting ones first
    var sortedSessions: [Session] {
        activeSessions.sorted { a, b in
            let aWaiting = appState.waitingSessions.contains(a.id)
            let bWaiting = appState.waitingSessions.contains(b.id)
            if aWaiting != bWaiting {
                return aWaiting  // Waiting sessions first
            }
            return a.createdAt > b.createdAt  // Then by most recent
        }
    }

    var mainProjects: [Project] {
        allProjects.filter { $0.category == .main }
    }

    var clientProjects: [Project] {
        allProjects.filter { $0.category == .client }
    }

    var devProjects: [Project] {
        allProjects.filter { $0.category == .dev }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Active sessions
            if !activeSessions.isEmpty {
                HStack {
                    Text("ACTIVE SESSIONS")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    // Show waiting count badge
                    if waitingCount > 0 {
                        Text("\(waitingCount) waiting")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)

                // Sort sessions: waiting ones first
                ForEach(sortedSessions.prefix(5)) { session in
                    MenuBarSessionRow(session: session, allProjects: allProjects)
                }

                Divider()
                    .padding(.vertical, 4)
            }

            // Quick access to projects
            Text("NEW CHAT IN...")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)

            ForEach(mainProjects) { project in
                MenuBarProjectRow(project: project)
            }

            Divider()
                .padding(.vertical, 2)

            ForEach(clientProjects) { project in
                MenuBarProjectRow(project: project)
            }

            Divider()
                .padding(.vertical, 4)

            Button("Quit Claude Hub") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(width: 220)
        .padding(.vertical, 4)
    }
}

struct MenuBarSessionRow: View {
    @EnvironmentObject var appState: AppState
    let session: Session
    let allProjects: [Project]
    @State private var isHovered = false

    var projectName: String {
        allProjects.first { $0.path == session.projectPath }?.name ?? "Unknown"
    }

    var isWaiting: Bool {
        appState.waitingSessions.contains(session.id)
    }

    var body: some View {
        Button {
            // Just open the app - user can select session in their preferred window
            NSApplication.shared.activate(ignoringOtherApps: true)
        } label: {
            HStack {
                // Orange dot for waiting, green dot for active
                Circle()
                    .fill(isWaiting ? Color.orange : Color.green)
                    .frame(width: 6, height: 6)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(session.name)
                            .font(.system(size: 12))
                            .lineLimit(1)

                        if isWaiting {
                            Text("waiting")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.orange)
                        }
                    }

                    Text(projectName)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isHovered ? Color.white.opacity(0.1) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct MenuBarProjectRow: View {
    let project: Project
    @State private var isHovered = false

    var body: some View {
        Button {
            // Just open the app - user can select project in their preferred window
            NSApplication.shared.activate(ignoringOtherApps: true)
        } label: {
            HStack {
                Image(systemName: project.icon)
                    .font(.system(size: 11))
                    .frame(width: 16)

                Text(project.name)
                    .font(.system(size: 12))

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(isHovered ? Color.white.opacity(0.1) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// Preview available in Xcode only
