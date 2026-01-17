import SwiftUI
import SwiftData

struct ProjectsView: View {
    @Query(sort: \Project.name) private var allProjects: [Project]

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
        NavigationStack {
            List {
                if !mainProjects.isEmpty {
                    Section("Projects") {
                        ForEach(mainProjects) { project in
                            NavigationLink(destination: ProjectDetailView(project: project)) {
                                ProjectRow(project: project)
                            }
                        }
                    }
                }

                if !clientProjects.isEmpty {
                    Section("Clients") {
                        ForEach(clientProjects) { project in
                            NavigationLink(destination: ProjectDetailView(project: project)) {
                                ProjectRow(project: project)
                            }
                        }
                    }
                }

                if !devProjects.isEmpty {
                    Section("Development") {
                        ForEach(devProjects) { project in
                            NavigationLink(destination: ProjectDetailView(project: project)) {
                                ProjectRow(project: project)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Projects")
            .listStyle(.insetGrouped)
            .overlay {
                if allProjects.isEmpty {
                    ContentUnavailableView(
                        "No Projects",
                        systemImage: "folder",
                        description: Text("Projects will appear here once synced from your Mac")
                    )
                }
            }
        }
    }
}

struct ProjectRow: View {
    let project: Project

    var activeCount: Int {
        project.sessions.filter { !$0.isCompleted }.count
    }

    var waitingCount: Int {
        project.sessions.filter { $0.isWaitingForInput && !$0.isCompleted }.count
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: project.icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.body)

                if activeCount > 0 {
                    Text("\(activeCount) active session\(activeCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if waitingCount > 0 {
                Text("\(waitingCount)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange)
                    .cornerRadius(10)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ProjectsView()
        .modelContainer(for: [Project.self, Session.self, ProjectGroup.self], inMemory: true)
}
