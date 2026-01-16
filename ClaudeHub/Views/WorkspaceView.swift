import SwiftUI

struct WorkspaceView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var windowState: WindowState
    let project: Project

    var sessions: [Session] {
        appState.sessionsFor(project: project)
    }

    func goBack() {
        withAnimation(.spring(response: 0.3)) {
            windowState.selectedProject = nil
            windowState.activeSession = nil
        }
    }

    var body: some View {
        HSplitView {
            // Sidebar
            SessionSidebar(project: project, goBack: goBack)
                .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)

            // Terminal area
            TerminalArea(project: project)
                .frame(minWidth: 500)
        }
        .background {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
        }
        .onAppear {
            // First, create sessions for any active projects from ACTIVE-PROJECTS.md
            let _ = appState.createSessionsForActiveProjects(project: project)

            // Get all sessions for this project
            let projectSessions = appState.sessionsFor(project: project)

            if projectSessions.isEmpty {
                // No active projects found, create a generic chat session
                let newSession = appState.createSession(for: project)
                windowState.activeSession = newSession
            } else if windowState.activeSession == nil {
                // Select the first session if none active
                windowState.activeSession = projectSessions.first
            }
        }
    }
}

struct SessionSidebar: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var windowState: WindowState
    let project: Project
    let goBack: () -> Void
    @State private var isBackHovered = false
    @State private var isCreatingTask = false
    @State private var newTaskName = ""
    @FocusState private var isTaskFieldFocused: Bool

    var sessions: [Session] {
        appState.sessionsFor(project: project)
    }

    var projectLinkedSessions: [Session] {
        sessions.filter { $0.isProjectLinked }
    }

    var taskSessions: [Session] {
        sessions.filter { !$0.isProjectLinked }
    }

    func createTask() {
        let name = newTaskName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            isCreatingTask = false
            newTaskName = ""
            return
        }

        let newSession = appState.createSession(for: project, name: name)
        windowState.activeSession = newSession
        isCreatingTask = false
        newTaskName = ""
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                // Header row - fixed height
                VStack(alignment: .leading, spacing: 12) {
                    // Back button - subtle
                    Button(action: goBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .medium))
                            Text("Back")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isBackHovered ? Color.white.opacity(0.12) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { isBackHovered = $0 }

                    // Project name with icon - prominent
                    HStack(spacing: 10) {
                        Image(systemName: project.icon)
                            .font(.system(size: 20))
                            .foregroundStyle(.primary)

                        Text(project.name)
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)

                Divider()

                // Task list - fills remaining space
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // New Task button/input
                        if isCreatingTask {
                            HStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.blue)

                                TextField("Task name...", text: $newTaskName)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 13))
                                    .focused($isTaskFieldFocused)
                                    .onSubmit { createTask() }
                                    .onExitCommand {
                                        isCreatingTask = false
                                        newTaskName = ""
                                    }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                            .padding(.horizontal, 12)
                            .onAppear { isTaskFieldFocused = true }
                        } else {
                            Button {
                                isCreatingTask = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("New Task")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 12)
                        }

                        // Active Projects Section (from ACTIVE-PROJECTS.md)
                        if !projectLinkedSessions.isEmpty {
                            Text("ACTIVE PROJECTS")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .tracking(1.2)
                                .padding(.horizontal, 16)
                                .padding(.top, 4)

                            LazyVStack(spacing: 4) {
                                ForEach(projectLinkedSessions) { session in
                                    TaskRow(session: session, project: project)
                                }
                            }
                        }

                        // Tasks Section
                        if !taskSessions.isEmpty {
                            Text("TASKS")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .tracking(1.2)
                                .padding(.horizontal, 16)
                                .padding(.top, 4)

                            LazyVStack(spacing: 4) {
                                ForEach(taskSessions) { session in
                                    TaskRow(session: session, project: project)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
        .background(
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
        )
    }
}

struct TaskRow: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var windowState: WindowState
    let session: Session
    let project: Project
    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editedName: String = ""

    var isActive: Bool {
        windowState.activeSession?.id == session.id
    }

    var isWaiting: Bool {
        appState.waitingSessions.contains(session.id)
    }

    var isLogged: Bool {
        session.lastSessionSummary != nil && !session.lastSessionSummary!.isEmpty
    }

    /// Status color: green (active/logged), orange (waiting), gray (inactive)
    var statusColor: Color {
        if isActive { return .green }
        if isWaiting { return .orange }
        if isLogged { return .green.opacity(0.6) }
        return Color.gray.opacity(0.4)
    }

    var body: some View {
        HStack(spacing: 10) {
            // Status indicator with logged checkmark
            ZStack {
                if isActive {
                    Circle()
                        .fill(Color.green.opacity(0.3))
                        .frame(width: 16, height: 16)
                } else if isWaiting {
                    Circle()
                        .fill(Color.orange.opacity(0.3))
                        .frame(width: 16, height: 16)
                }

                if isLogged && !isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.green)
                } else {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                }
            }
            .frame(width: 16, height: 16)

            if isEditing {
                TextField("Task name", text: $editedName, onCommit: {
                    appState.updateSessionName(session, name: editedName)
                    isEditing = false
                })
                .textFieldStyle(.plain)
                .font(.system(size: 13))
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(session.name)
                            .font(.system(size: 13))
                            .foregroundStyle(isActive ? .primary : .secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        // Show "waiting" badge when Claude needs input
                        if isWaiting {
                            Text("waiting")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(Capsule())
                        }

                        // Show "Logged" badge for tasks with summaries
                        if isLogged && !isWaiting {
                            Text("Logged")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }

                    // Show summary preview if logged
                    if let summary = session.lastSessionSummary, !summary.isEmpty {
                        Text(summary)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                            .truncationMode(.tail)
                    }

                    // Show "Project" badge for linked sessions
                    if session.isProjectLinked {
                        Text("Project")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            // Edit and delete buttons on hover
            if isHovered && !isEditing {
                HStack(spacing: 6) {
                    Button {
                        editedName = session.name
                        isEditing = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        // Clear window's active session if we're deleting it
                        if windowState.activeSession?.id == session.id {
                            windowState.activeSession = nil
                        }
                        appState.deleteSession(session)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isActive ? Color.blue.opacity(0.15) : (isHovered ? Color.white.opacity(0.08) : Color.clear))
        }
        .overlay {
            if isActive {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            }
        }
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            editedName = session.name
            isEditing = true
        }
        .onTapGesture(count: 1) {
            windowState.activeSession = session
            // Clear waiting state when user views this session
            appState.clearSessionWaiting(session)
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct TerminalHeader: View {
    @EnvironmentObject var appState: AppState
    let session: Session
    let project: Project
    @Binding var showLogSheet: Bool
    @State private var isPulsing = false
    @State private var isLogHovered = false

    var body: some View {
        HStack(spacing: 14) {
            // Animated status indicator
            ZStack {
                // Outer glow ring (animated)
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 20, height: 20)
                    .scaleEffect(isPulsing ? 1.3 : 1.0)
                    .opacity(isPulsing ? 0.0 : 0.6)

                // Middle ring
                Circle()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: 14, height: 14)

                // Core dot
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .shadow(color: Color.green.opacity(0.8), radius: 6)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(session.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let description = session.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer()

            // Log Task button - more prominent
            Button {
                showLogSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 12, weight: .medium))
                    Text("Log Task")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(Capsule())
                .shadow(color: Color.blue.opacity(isLogHovered ? 0.5 : 0.3), radius: isLogHovered ? 8 : 4)
                .scaleEffect(isLogHovered ? 1.03 : 1.0)
            }
            .buttonStyle(.plain)
            .onHover { isLogHovered = $0 }

            // Running status badge
            HStack(spacing: 5) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                Text("Running")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.green)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.green.opacity(0.12))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            ZStack {
                // Frosted glass base
                VisualEffectView(material: .headerView, blendingMode: .withinWindow)

                // Subtle top highlight
                LinearGradient(
                    colors: [Color.white.opacity(0.08), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
    }
}

struct TerminalArea: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var windowState: WindowState
    let project: Project
    @State private var showLogSheet = false

    var body: some View {
        Group {
            if let session = windowState.activeSession {
                VStack(spacing: 0) {
                    TerminalHeader(session: session, project: project, showLogSheet: $showLogSheet)

                    // Subtle separator line with gradient
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2), Color.blue.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 1)

                    TerminalView(session: session)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.05),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
                .shadow(color: Color.blue.opacity(0.1), radius: 20, x: 0, y: 0)
                .padding(14)
                .sheet(isPresented: $showLogSheet) {
                    LogTaskSheet(session: session, project: project, isPresented: $showLogSheet)
                }
            } else {
                // Enhanced empty state
                VStack(spacing: 20) {
                    ZStack {
                        // Background glow
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 120, height: 120)
                            .blur(radius: 30)

                        Image(systemName: "terminal.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.4), Color.white.opacity(0.2)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }

                    VStack(spacing: 8) {
                        Text("No Active Session")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Text("Select a task from the sidebar or create a new one")
                            .font(.system(size: 13))
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    ZStack {
                        Color.black.opacity(0.4)

                        // Subtle radial gradient for depth
                        RadialGradient(
                            colors: [Color.blue.opacity(0.05), Color.clear],
                            center: .center,
                            startRadius: 50,
                            endRadius: 300
                        )
                    }
                )
            }
        }
    }
}

// MARK: - Log Task Sheet

struct LogTaskSheet: View {
    @EnvironmentObject var appState: AppState
    let session: Session
    let project: Project
    @Binding var isPresented: Bool

    // Form fields
    @State private var billableDescription: String = ""
    @State private var estimatedHours: String = ""
    @State private var actualHours: String = ""
    @State private var notes: String = ""

    // State
    @State private var isGenerating = true
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var savedSuccessfully = false

    var canSave: Bool {
        !billableDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !actualHours.isEmpty &&
        Double(actualHours) != nil &&
        !isSaving
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Log Task")
                        .font(.system(size: 16, weight: .semibold))
                    Text(session.name)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(.ultraThinMaterial)

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Billable Description
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Billable Description")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)

                        if isGenerating {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Generating summary...")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(height: 32)
                        } else {
                            TextField("e.g., Designed social media graphics", text: $billableDescription)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                                .padding(10)
                                .background(Color.black.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        }
                    }

                    // Hours row
                    HStack(spacing: 16) {
                        // Estimated Hours
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Est. Hours")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)

                            TextField("0.5", text: $estimatedHours)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                                .padding(10)
                                .frame(width: 80)
                                .background(Color.black.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        }

                        // Actual Hours
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Actual Hours *")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)

                            TextField("0.5", text: $actualHours)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                                .padding(10)
                                .frame(width: 80)
                                .background(Color.black.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(actualHours.isEmpty ? Color.orange.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                                )
                        }

                        Spacer()
                    }

                    // Notes (optional)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes (optional)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)

                        TextEditor(text: $notes)
                            .font(.system(size: 13))
                            .frame(minHeight: 60)
                            .padding(8)
                            .background(Color.black.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }

                    if let error = saveError {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                    }

                    if savedSuccessfully {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Task logged successfully!")
                                .foregroundStyle(.green)
                        }
                        .font(.system(size: 12))
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Button {
                    saveLog()
                } label: {
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 60)
                    } else {
                        Text("Save Log")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
            .padding()
        }
        .frame(width: 500, height: 420)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .onAppear {
            generateSummary()
        }
    }

    func generateSummary() {
        // Get terminal content from the session's controller
        guard let controller = appState.terminalControllers[session.id] else {
            isGenerating = false
            billableDescription = session.name
            estimatedHours = "0.5"
            return
        }

        let content = controller.getTerminalContent()

        if content.isEmpty {
            isGenerating = false
            billableDescription = session.name
            estimatedHours = "0.5"
            return
        }

        ClaudeAPI.shared.generateBillableSummary(from: content, taskName: session.name) { summary in
            isGenerating = false
            if let summary = summary {
                billableDescription = summary.description
                estimatedHours = String(format: "%.2f", summary.estimatedHours)
            } else {
                // Fallback to task name
                billableDescription = session.name
                estimatedHours = "0.5"
            }
        }
    }

    func saveLog() {
        guard canSave else { return }

        isSaving = true
        saveError = nil

        let estHrs = Double(estimatedHours) ?? 0.5
        let actHrs = Double(actualHours) ?? 0.5

        Task {
            // Save locally
            appState.updateSessionSummary(session, summary: billableDescription)

            // Sync to Google Sheets
            do {
                let result = try await GoogleSheetsService.shared.logTask(
                    workspace: project.name,
                    project: nil,  // TODO: Add project support
                    task: session.name,
                    billableDescription: billableDescription,
                    estimatedHours: estHrs,
                    actualHours: actHrs,
                    status: "completed",
                    notes: notes
                )

                await MainActor.run {
                    isSaving = false
                    if result.success {
                        savedSuccessfully = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            isPresented = false
                        }
                    } else if result.needs_auth == true {
                        saveError = "Google Sheets not authorized."
                    } else {
                        saveError = "Saved locally. Sheets sync: \(result.error ?? "unknown error")"
                        savedSuccessfully = true
                    }
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    saveError = "Saved locally. Sheets sync failed."
                    savedSuccessfully = true
                }
            }
        }
    }
}

// Preview available in Xcode only
