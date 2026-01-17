import SwiftUI
import SwiftData

struct IOSSettingsView: View {
    @Query(sort: \Project.name) private var projects: [Project]
    @Query private var sessions: [Session]

    var body: some View {
        NavigationStack {
            List {
                // Sync Status Section
                Section {
                    CloudKitStatusView()
                } header: {
                    Text("Sync")
                }

                // Stats Section
                Section {
                    HStack {
                        Text("Projects")
                        Spacer()
                        Text("\(projects.count)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Total Sessions")
                        Spacer()
                        Text("\(sessions.count)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Active Sessions")
                        Spacer()
                        Text("\(sessions.filter { !$0.isCompleted }.count)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Completed")
                        Spacer()
                        Text("\(sessions.filter { $0.isCompleted }.count)")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Data")
                }

                // Notifications Section
                Section {
                    Toggle("Push Notifications", isOn: .constant(true))

                    Toggle("Sound", isOn: .constant(true))

                    Toggle("Badge", isOn: .constant(true))
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Get notified when Claude is waiting for input on your Mac")
                }

                // About Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://github.com/buzzboxmedia/claudehub")!) {
                        HStack {
                            Text("GitHub")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    IOSSettingsView()
        .modelContainer(for: [Project.self, Session.self, ProjectGroup.self], inMemory: true)
}
