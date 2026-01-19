import Foundation

/// Service for syncing tasks to Google Sheets via Python script
class GoogleSheetsService {
    static let shared = GoogleSheetsService()

    private let scriptPath: String

    private init() {
        // Find the script relative to the executable or in common locations
        let possiblePaths = [
            Bundle.main.bundlePath + "/../scripts/sheets_sync.py",
            NSHomeDirectory() + "/Code/claudehub/scripts/sheets_sync.py",
            "/Users/baronmiller/Code/claudehub/scripts/sheets_sync.py"
        ]

        scriptPath = possiblePaths.first { FileManager.default.fileExists(atPath: $0) }
            ?? possiblePaths.last!
    }

    struct LogResult: Codable {
        let success: Bool
        let spreadsheet_id: String?
        let url: String?
        let error: String?
        let needs_auth: Bool?
        let logged: LoggedTask?

        struct LoggedTask: Codable {
            let date: String
            let time: String
            let workspace: String?
            let project: String?
            let task: String
            let description: String?
            let est_hours: Double?
            let actual_hours: Double?
            let status: String
        }
    }

    /// Log a task to Google Sheets
    func logTask(
        workspace: String,
        project: String?,
        task: String,
        billableDescription: String,
        estimatedHours: Double,
        actualHours: Double,
        status: String = "completed",
        notes: String
    ) async throws -> LogResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [
            scriptPath,
            "log",
            "--workspace", workspace,
            "--project", project ?? "",
            "--task", task,
            "--description", billableDescription,
            "--est-hours", String(estimatedHours),
            "--actual-hours", String(actualHours),
            "--status", status,
            "--notes", notes
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                do {
                    try process.run()
                    process.waitUntilExit()

                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                    // Try to parse stdout first, then stderr
                    let jsonData = outputData.isEmpty ? errorData : outputData

                    if let result = try? JSONDecoder().decode(LogResult.self, from: jsonData) {
                        continuation.resume(returning: result)
                    } else {
                        let output = String(data: jsonData, encoding: .utf8) ?? "Unknown error"
                        continuation.resume(returning: LogResult(
                            success: false,
                            spreadsheet_id: nil,
                            url: nil,
                            error: output,
                            needs_auth: nil,
                            logged: nil
                        ))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Create a project in Google Sheets
    func createProject(workspace: String, project: String) async {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [
            scriptPath,
            "create-project",
            "--workspace", workspace,
            "--project", project
        ]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("Failed to sync project to sheets: \(error)")
        }
    }

    /// Create a task in Google Sheets
    func createTask(workspace: String, project: String?, task: String, description: String = "") async {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [
            scriptPath,
            "create-task",
            "--workspace", workspace,
            "--project", project ?? "",
            "--task", task,
            "--description", description
        ]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("Failed to sync task to sheets: \(error)")
        }
    }

    // MARK: - Task Fetching

    struct SheetTask: Codable, Identifiable {
        let row: Int
        let date: String
        let time: String
        let workspace: String
        let project: String
        let task: String
        let description: String
        let est_hours: String
        let actual_hours: String
        let status: String
        let notes: String

        var id: Int { row }

        var isActive: Bool {
            status == "active" || status == "created"
        }
    }

    struct FetchTasksResult: Codable {
        let success: Bool
        let tasks: [SheetTask]?
        let workspace: String?
        let error: String?
    }

    /// Fetch tasks for a workspace from Google Sheets
    func fetchTasks(workspace: String, status: String? = nil) async throws -> [SheetTask] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")

        var args = [scriptPath, "get-tasks", "--workspace", workspace]
        if let status = status {
            args.append(contentsOf: ["--status", status])
        }
        process.arguments = args

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                do {
                    try process.run()
                    process.waitUntilExit()

                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()

                    if let result = try? JSONDecoder().decode(FetchTasksResult.self, from: outputData) {
                        if result.success {
                            continuation.resume(returning: result.tasks ?? [])
                        } else {
                            continuation.resume(returning: [])
                        }
                    } else {
                        continuation.resume(returning: [])
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    struct UpdateTaskResult: Codable {
        let success: Bool
        let error: String?
    }

    /// Update a task in Google Sheets
    func updateTask(
        workspace: String,
        taskName: String,
        status: String? = nil,
        notes: String? = nil,
        description: String? = nil,
        actualHours: Double? = nil
    ) async throws -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")

        var args = [scriptPath, "update-task", "--workspace", workspace, "--task", taskName]

        if let status = status {
            args.append(contentsOf: ["--status", status])
        }
        if let notes = notes {
            args.append(contentsOf: ["--notes", notes])
        }
        if let description = description {
            args.append(contentsOf: ["--description", description])
        }
        if let hours = actualHours {
            args.append(contentsOf: ["--actual-hours", String(hours)])
        }

        process.arguments = args

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                do {
                    try process.run()
                    process.waitUntilExit()

                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()

                    if let result = try? JSONDecoder().decode(UpdateTaskResult.self, from: outputData) {
                        continuation.resume(returning: result.success)
                    } else {
                        continuation.resume(returning: false)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Check if authentication is set up
    func checkAuth() async -> Bool {
        let tokenPath = NSHomeDirectory() + "/.claudehub/sheets_token.json"
        return FileManager.default.fileExists(atPath: tokenPath)
    }

    /// Initialize the spreadsheet (creates if needed)
    func initSpreadsheet() async throws -> LogResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [scriptPath, "init"]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                do {
                    try process.run()
                    process.waitUntilExit()

                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                    let jsonData = outputData.isEmpty ? errorData : outputData

                    if let result = try? JSONDecoder().decode(LogResult.self, from: jsonData) {
                        continuation.resume(returning: result)
                    } else {
                        let output = String(data: jsonData, encoding: .utf8) ?? "Unknown error"
                        continuation.resume(returning: LogResult(
                            success: false,
                            spreadsheet_id: nil,
                            url: nil,
                            error: output,
                            needs_auth: nil,
                            logged: nil
                        ))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Run the OAuth authorization flow (opens browser)
    func runAuthFlow() async throws -> LogResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [scriptPath, "auth"]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                do {
                    try process.run()
                    process.waitUntilExit()

                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                    let jsonData = outputData.isEmpty ? errorData : outputData

                    if let result = try? JSONDecoder().decode(LogResult.self, from: jsonData) {
                        continuation.resume(returning: result)
                    } else {
                        let output = String(data: jsonData, encoding: .utf8) ?? "Unknown error"
                        continuation.resume(returning: LogResult(
                            success: false,
                            spreadsheet_id: nil,
                            url: nil,
                            error: output,
                            needs_auth: nil,
                            logged: nil
                        ))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
