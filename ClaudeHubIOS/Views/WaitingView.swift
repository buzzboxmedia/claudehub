import SwiftUI
import SwiftData

struct WaitingView: View {
    @Query(
        filter: #Predicate<Session> { $0.isWaitingForInput && !$0.isCompleted },
        sort: \Session.lastAccessedAt,
        order: .reverse
    )
    private var waitingSessions: [Session]

    @Query(sort: \Project.name) private var allProjects: [Project]

    func projectName(for session: Session) -> String {
        allProjects.first { $0.path == session.projectPath }?.name
            ?? URL(fileURLWithPath: session.projectPath).lastPathComponent
    }

    var body: some View {
        NavigationStack {
            Group {
                if waitingSessions.isEmpty {
                    ContentUnavailableView(
                        "All Caught Up",
                        systemImage: "checkmark.circle",
                        description: Text("No sessions are waiting for input")
                    )
                } else {
                    List {
                        ForEach(waitingSessions) { session in
                            NavigationLink(destination: SessionDetailView(session: session)) {
                                WaitingSessionRow(
                                    session: session,
                                    projectName: projectName(for: session)
                                )
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Waiting")
        }
    }
}

struct WaitingSessionRow: View {
    let session: Session
    let projectName: String
    @State private var quickReply = ""
    @State private var isSending = false

    let quickReplies = ["yes", "no", "continue"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Session info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.name)
                        .font(.headline)

                    Text(projectName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Pulsing indicator
                Circle()
                    .fill(Color.orange)
                    .frame(width: 12, height: 12)
                    .overlay {
                        Circle()
                            .stroke(Color.orange.opacity(0.5), lineWidth: 2)
                            .scaleEffect(1.5)
                    }
            }

            // Quick reply buttons inline
            HStack(spacing: 8) {
                ForEach(quickReplies, id: \.self) { text in
                    Button {
                        sendReply(text)
                    } label: {
                        Text(text)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .cornerRadius(14)
                    }
                    .disabled(isSending)
                }

                Spacer()

                if isSending {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func sendReply(_ text: String) {
        isSending = true

        Task {
            do {
                try await QuickReplyService.shared.send(reply: text, to: session)
                await MainActor.run {
                    isSending = false
                }
            } catch {
                await MainActor.run {
                    isSending = false
                }
            }
        }
    }
}

#Preview {
    WaitingView()
        .modelContainer(for: [Project.self, Session.self, ProjectGroup.self], inMemory: true)
}
