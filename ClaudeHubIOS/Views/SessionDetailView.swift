import SwiftUI
import SwiftData

struct SessionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: Session
    @State private var quickReply = ""
    @State private var showingLog = false
    @State private var isSending = false
    @State private var showingSentConfirmation = false

    var projectName: String {
        URL(fileURLWithPath: session.projectPath).lastPathComponent
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Session info card
                SessionInfoCard(session: session, projectName: projectName)

                // Summary section
                if let summary = session.lastSessionSummary, !summary.isEmpty {
                    SummaryCard(summary: summary)
                }

                // Quick actions
                QuickActionsSection(session: session)

                // Quick reply (if waiting)
                if session.isWaitingForInput && !session.isCompleted {
                    QuickReplySection(
                        reply: $quickReply,
                        isSending: isSending,
                        onSend: sendQuickReply
                    )
                }

                // Parker briefing (if available)
                if let briefing = session.parkerBriefing, !briefing.isEmpty {
                    BriefingCard(briefing: briefing)
                }
            }
            .padding()
        }
        .navigationTitle(session.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if session.hasLog {
                    Button {
                        showingLog = true
                    } label: {
                        Image(systemName: "doc.text")
                    }
                }
            }
        }
        .sheet(isPresented: $showingLog) {
            LogViewerSheet(session: session)
        }
        .overlay {
            if showingSentConfirmation {
                SentConfirmationOverlay()
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private func sendQuickReply() {
        guard !quickReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isSending = true

        Task {
            do {
                try await QuickReplyService.shared.send(reply: quickReply, to: session)

                await MainActor.run {
                    quickReply = ""
                    isSending = false
                    showingSentConfirmation = true

                    // Hide confirmation after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            showingSentConfirmation = false
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    // Could show error alert here
                }
            }
        }
    }
}

// MARK: - Session Info Card

struct SessionInfoCard: View {
    let session: Session
    let projectName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Status badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)

                    Text(statusText)
                        .font(.caption.bold())
                        .foregroundStyle(statusColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(statusColor.opacity(0.1))
                .cornerRadius(8)

                Spacer()

                // Created date
                Text(session.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Project
            HStack {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                Text(projectName)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)

            // Active project link
            if let activeProject = session.activeProjectName {
                HStack {
                    Image(systemName: "link")
                        .foregroundStyle(.blue)
                    Text(activeProject)
                        .foregroundStyle(.blue)
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    var statusColor: Color {
        if session.isCompleted { return .gray }
        if session.isWaitingForInput { return .orange }
        return .green
    }

    var statusText: String {
        if session.isCompleted { return "Completed" }
        if session.isWaitingForInput { return "Waiting" }
        return "Active"
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let summary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Summary", systemImage: "text.alignleft")
                .font(.headline)

            Text(summary)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Quick Actions Section

struct QuickActionsSection: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.headline)

            HStack(spacing: 12) {
                // Mark Complete / Reopen
                if session.isCompleted {
                    ActionButton(
                        title: "Reopen",
                        icon: "arrow.uturn.backward.circle",
                        color: .blue
                    ) {
                        session.isCompleted = false
                        session.completedAt = nil
                    }
                } else {
                    ActionButton(
                        title: "Complete",
                        icon: "checkmark.circle",
                        color: .green
                    ) {
                        session.isCompleted = true
                        session.completedAt = Date()
                    }
                }

                // View on Mac (placeholder - could use Handoff)
                ActionButton(
                    title: "Open Mac",
                    icon: "desktopcomputer",
                    color: .blue
                ) {
                    // Could trigger Handoff or deep link
                }
            }
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.1))
            .foregroundStyle(color)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Reply Section

struct QuickReplySection: View {
    @Binding var reply: String
    var isSending: Bool
    let onSend: () -> Void

    let quickReplies = ["yes", "no", "continue", "skip", "stop"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Quick Reply", systemImage: "bubble.left")
                .font(.headline)
                .foregroundStyle(.orange)

            // Preset buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickReplies, id: \.self) { text in
                        Button {
                            reply = text
                            onSend()
                        } label: {
                            Text(text)
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.orange.opacity(0.1))
                                .foregroundStyle(.orange)
                                .cornerRadius(20)
                        }
                        .disabled(isSending)
                    }
                }
            }

            // Custom reply
            HStack(spacing: 12) {
                TextField("Type a reply...", text: $reply)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isSending)

                Button(action: onSend) {
                    if isSending {
                        ProgressView()
                            .frame(width: 44, height: 44)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .frame(width: 44, height: 44)
                            .background(Color.orange)
                            .foregroundStyle(.white)
                            .cornerRadius(22)
                    }
                }
                .disabled(reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }

            Text("Reply will be sent to your Mac via CloudKit")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Briefing Card

struct BriefingCard: View {
    let briefing: String
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Label("Parker Briefing", systemImage: "person.badge.clock")
                        .font(.headline)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(briefing)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Log Viewer Sheet

struct LogViewerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let session: Session
    @State private var logContent: String = "Loading..."

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(logContent)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle("Session Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: logContent)
                }
            }
        }
        .onAppear {
            loadLog()
        }
    }

    private func loadLog() {
        let logPath = session.actualLogPath

        if let content = try? String(contentsOf: logPath, encoding: .utf8) {
            logContent = content
        } else {
            logContent = "Unable to load log file."
        }
    }
}

// MARK: - Sent Confirmation Overlay

struct SentConfirmationOverlay: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("Reply Sent")
                .font(.headline)
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Project.self, Session.self, ProjectGroup.self, configurations: config)

    let session = Session(name: "Test Session", projectPath: "/test/path")
    session.isWaitingForInput = true
    session.lastSessionSummary = "Working on implementing the new feature"
    container.mainContext.insert(session)

    return NavigationStack {
        SessionDetailView(session: session)
    }
    .modelContainer(container)
}
