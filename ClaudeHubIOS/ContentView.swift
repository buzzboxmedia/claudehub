import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(
        filter: #Predicate<Session> { $0.isWaitingForInput && !$0.isCompleted },
        sort: \Session.lastAccessedAt,
        order: .reverse
    )
    private var waitingSessions: [Session]

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2")
                }

            ProjectsView()
                .tabItem {
                    Label("Projects", systemImage: "folder")
                }

            WaitingView()
                .tabItem {
                    Label("Waiting", systemImage: "bell.badge")
                }
                .badge(waitingSessions.count)

            IOSSettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Project.self, Session.self, ProjectGroup.self], inMemory: true)
}
