import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let project: Project

    var activeSessions: [Session] {
        project.sessions
            .filter { !$0.isCompleted }
            .sorted { $0.lastAccessedAt > $1.lastAccessedAt }
    }

    var completedSessions: [Session] {
        project.sessions
            .filter { $0.isCompleted }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    var taskGroups: [ProjectGroup] {
        project.taskGroups.sorted { $0.sortOrder < $1.sortOrder }
    }

    // Sessions not in any group
    var standaloneSessions: [Session] {
        activeSessions.filter { $0.taskGroup == nil && !$0.isProjectLinked }
    }

    // Sessions linked to ACTIVE-PROJECTS.md
    var projectLinkedSessions: [Session] {
        activeSessions.filter { $0.isProjectLinked }
    }

    var body: some View {
        List {
            // Active Projects from ACTIVE-PROJECTS.md
            if !projectLinkedSessions.isEmpty {
                Section("Active Projects") {
                    ForEach(projectLinkedSessions) { session in
                        NavigationLink(destination: SessionDetailView(session: session)) {
                            SessionRow(session: session)
                        }
                    }
                }
            }

            // Task Groups
            ForEach(taskGroups) { group in
                let groupSessions = activeSessions.filter { $0.taskGroup?.id == group.id }
                if !groupSessions.isEmpty {
                    Section(group.name) {
                        ForEach(groupSessions) { session in
                            NavigationLink(destination: SessionDetailView(session: session)) {
                                SessionRow(session: session)
                            }
                        }
                    }
                }
            }

            // Standalone Tasks
            if !standaloneSessions.isEmpty {
                Section("Tasks") {
                    ForEach(standaloneSessions) { session in
                        NavigationLink(destination: SessionDetailView(session: session)) {
                            SessionRow(session: session)
                        }
                    }
                }
            }

            // Completed
            if !completedSessions.isEmpty {
                Section("Completed") {
                    ForEach(completedSessions.prefix(10)) { session in
                        NavigationLink(destination: SessionDetailView(session: session)) {
                            SessionRow(session: session, showCompleted: true)
                        }
                    }
                }
            }
        }
        .navigationTitle(project.name)
        .listStyle(.insetGrouped)
        .overlay {
            if project.sessions.isEmpty {
                ContentUnavailableView(
                    "No Sessions",
                    systemImage: "terminal",
                    description: Text("Sessions will appear here once created on your Mac")
                )
            }
        }
    }
}

struct SessionRow: View {
    let session: Session
    var showCompleted: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            ZStack {
                if session.isWaitingForInput && !session.isCompleted {
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 24, height: 24)
                }

                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
            }
            .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(session.name)
                        .font(.body)
                        .foregroundStyle(showCompleted ? .secondary : .primary)
                        .lineLimit(1)

                    if session.isWaitingForInput && !session.isCompleted {
                        Text("waiting")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(4)
                    }

                    if session.isProjectLinked {
                        Text("Project")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                }

                if let summary = session.lastSessionSummary, !summary.isEmpty {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if session.hasLog {
                Image(systemName: "doc.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    var statusColor: Color {
        if session.isCompleted {
            return .gray
        }
        if session.isWaitingForInput {
            return .orange
        }
        if session.lastSessionSummary != nil {
            return .green.opacity(0.6)
        }
        return .green
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Project.self, Session.self, ProjectGroup.self, configurations: config)

    let project = Project(name: "Test Project", path: "/test/path", icon: "folder.fill", category: .main)
    container.mainContext.insert(project)

    return NavigationStack {
        ProjectDetailView(project: project)
    }
    .modelContainer(container)
}
