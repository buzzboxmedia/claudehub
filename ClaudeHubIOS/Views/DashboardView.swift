import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(
        filter: #Predicate<Session> { !$0.isCompleted },
        sort: \Session.lastAccessedAt,
        order: .reverse
    )
    private var activeSessions: [Session]

    @Query(sort: \Project.name) private var projects: [Project]

    var waitingSessions: [Session] {
        activeSessions.filter { $0.isWaitingForInput }
    }

    var recentSessions: [Session] {
        Array(activeSessions.prefix(5))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Waiting for input section
                    if !waitingSessions.isEmpty {
                        WaitingSection(sessions: waitingSessions)
                    }

                    // Recent activity
                    RecentActivitySection(sessions: recentSessions, projects: projects)

                    // Project summary
                    ProjectSummarySection(projects: projects)
                }
                .padding()
            }
            .navigationTitle("ClaudeHub")
            .background(Color(.systemGroupedBackground))
        }
    }
}

// MARK: - Waiting Section

struct WaitingSection: View {
    let sessions: [Session]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Waiting for Input", systemImage: "bell.badge")
                .font(.headline)
                .foregroundStyle(.orange)

            ForEach(sessions) { session in
                NavigationLink(destination: SessionDetailView(session: session)) {
                    WaitingSessionCard(session: session)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct WaitingSessionCard: View {
    let session: Session

    var projectName: String {
        URL(fileURLWithPath: session.projectPath).lastPathComponent
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(projectName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Recent Activity Section

struct RecentActivitySection: View {
    let sessions: [Session]
    let projects: [Project]

    func projectName(for session: Session) -> String {
        projects.first { $0.path == session.projectPath }?.name
            ?? URL(fileURLWithPath: session.projectPath).lastPathComponent
    }

    func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
                .foregroundStyle(.primary)

            if sessions.isEmpty {
                Text("No active sessions")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
            } else {
                VStack(spacing: 1) {
                    ForEach(sessions) { session in
                        NavigationLink(destination: SessionDetailView(session: session)) {
                            HStack {
                                // Status indicator
                                Circle()
                                    .fill(session.isWaitingForInput ? Color.orange : Color.green)
                                    .frame(width: 8, height: 8)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.name)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)

                                    Text(projectName(for: session))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(timeAgo(session.lastAccessedAt))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemGroupedBackground))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Project Summary Section

struct ProjectSummarySection: View {
    let projects: [Project]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Projects")
                .font(.headline)
                .foregroundStyle(.primary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(projects) { project in
                        NavigationLink(destination: ProjectDetailView(project: project)) {
                            ProjectSummaryCard(project: project)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct ProjectSummaryCard: View {
    let project: Project

    var activeCount: Int {
        project.sessions.filter { !$0.isCompleted }.count
    }

    var waitingCount: Int {
        project.sessions.filter { $0.isWaitingForInput && !$0.isCompleted }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: project.icon)
                    .font(.title2)
                    .foregroundStyle(.blue)

                Spacer()

                if waitingCount > 0 {
                    Text("\(waitingCount)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .cornerRadius(8)
                }
            }

            Text(project.name)
                .font(.headline)
                .foregroundStyle(.primary)

            Text("\(activeCount) active")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 120)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Project.self, Session.self, ProjectGroup.self], inMemory: true)
}
