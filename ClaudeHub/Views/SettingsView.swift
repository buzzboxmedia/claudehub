import SwiftUI
import SwiftData
import AppKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    // Fetch projects
    @Query(sort: \Project.name) private var allProjects: [Project]

    var mainProjects: [Project] {
        allProjects.filter { $0.category == .main }
    }

    var clientProjects: [Project] {
        allProjects.filter { $0.category == .client }
    }

    // Notification settings (bound to NotificationManager)
    @ObservedObject private var notificationManager = NotificationManager.shared

    // API Key
    @State private var apiKey: String = UserDefaults.standard.string(forKey: "anthropic_api_key") ?? ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Manage Projects")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider()

            // Main Projects Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("MAIN PROJECTS")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        addProject(category: .main)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                ForEach(mainProjects) { project in
                    ProjectRow(project: project)
                }
            }

            Divider()
                .padding(.vertical, 8)

            // Client Projects Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("CLIENTS")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        addProject(category: .client)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)

                ForEach(clientProjects) { project in
                    ProjectRow(project: project)
                }
            }

            Divider()
                .padding(.vertical, 8)

            // Notifications Section
            VStack(alignment: .leading, spacing: 12) {
                Text("NOTIFICATIONS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 10) {
                    // Main toggle
                    Toggle("Notify when Claude is waiting", isOn: $notificationManager.notificationsEnabled)
                        .font(.system(size: 12))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .padding(.horizontal, 16)

                    // Sub-options (indented, dimmed when disabled)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Style")
                                .font(.system(size: 12))
                                .foregroundStyle(notificationManager.notificationsEnabled ? .primary : .tertiary)

                            Spacer()

                            Picker("", selection: $notificationManager.notificationStyle) {
                                ForEach(NotificationStyle.allCases, id: \.self) { style in
                                    Text(style.rawValue).tag(style)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 100)
                            .disabled(!notificationManager.notificationsEnabled)
                        }

                        Toggle("Play sound", isOn: $notificationManager.playSound)
                            .font(.system(size: 12))
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .foregroundStyle(notificationManager.notificationsEnabled ? .primary : .tertiary)
                            .disabled(!notificationManager.notificationsEnabled)

                        Toggle("Only when in background", isOn: $notificationManager.onlyWhenInBackground)
                            .font(.system(size: 12))
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .foregroundStyle(notificationManager.notificationsEnabled ? .primary : .tertiary)
                            .disabled(!notificationManager.notificationsEnabled)
                    }
                    .padding(.leading, 24)
                    .padding(.horizontal, 16)
                }
            }

            Divider()
                .padding(.vertical, 8)

            // API Key Section
            VStack(alignment: .leading, spacing: 8) {
                Text("API KEY")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 6) {
                    SecureField("Anthropic API Key", text: $apiKey)
                        .font(.system(size: 12))
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: apiKey) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "anthropic_api_key")
                        }

                    Text("Used for AI summaries when closing tasks")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
            }

            Spacer()

            Divider()

            // About Section
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("ABOUT")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                HStack {
                    Text("ClaudeHub")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text("v\(AppVersion.version)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)

                HStack {
                    Text("Build: \(AppVersion.buildHash)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button("Check for Updates") {
                        checkForUpdates()
                    }
                    .font(.system(size: 10))
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            Divider()

            // Footer
            HStack {
                Text("Click + to add a folder from your Mac")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(12)
        }
        .frame(width: 350, height: 560)
        .background(.ultraThinMaterial)
    }

    func checkForUpdates() {
        // Open GitHub releases page
        if let url = URL(string: "https://github.com/buzzboxmedia/claudehub/releases") {
            NSWorkspace.shared.open(url)
        }
    }

    func addProject(category: ProjectCategory) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder to add as a project"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                let name = url.lastPathComponent
                let path = url.path
                let icon = "folder.fill"

                let project = Project(name: name, path: path, icon: icon, category: category)
                modelContext.insert(project)
            }
        }
    }
}

struct ProjectRow: View {
    @Environment(\.modelContext) private var modelContext
    let project: Project
    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: project.icon)
                .font(.system(size: 14))
                .frame(width: 24, height: 24)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.system(size: 13, weight: .medium))

                Text(displayPath(project.path))
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
                    .lineLimit(1)
            }

            Spacer()

            if isHovered {
                Button {
                    editProjectPath()
                } label: {
                    Image(systemName: "folder.badge.gearshape")
                        .font(.system(size: 14))
                        .foregroundStyle(.blue.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Change folder path")

                Button {
                    modelContext.delete(project)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isHovered ? Color.white.opacity(0.05) : Color.clear)
        .cornerRadius(6)
        .onHover { isHovered = $0 }
    }

    func editProjectPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select new folder for \(project.name)"
        panel.directoryURL = URL(fileURLWithPath: project.path)

        panel.begin { response in
            if response == .OK, let url = panel.url {
                project.path = url.path
            }
        }
    }

    func displayPath(_ path: String) -> String {
        // Show just the last 2 path components for cleaner look
        let components = path.split(separator: "/")
        if components.count >= 2 {
            let lastTwo = components.suffix(2).joined(separator: "/")
            return ".../" + lastTwo
        }
        return path
    }
}

// Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AppState())
    }
}
