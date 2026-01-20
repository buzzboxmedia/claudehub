import Foundation
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.buzzbox.claudehub", category: "TaskImportService")

/// Service for importing existing task folders as sessions
/// Scans {projectPath}/tasks/ for TASK.md files and creates sessions if they don't exist
class TaskImportService {
    static let shared = TaskImportService()

    private let fileManager = FileManager.default
    private let taskFolderService = TaskFolderService.shared

    private init() {}

    /// Import all tasks from a project's tasks directory
    /// Returns the number of tasks imported
    @MainActor
    func importTasks(for project: Project, modelContext: ModelContext) -> Int {
        let tasksDir = taskFolderService.tasksDirectory(for: project.path)

        guard fileManager.fileExists(atPath: tasksDir.path) else {
            logger.info("No tasks directory found for \(project.name)")
            return 0
        }

        // Get existing sessions linked to task folders
        let existingTaskPaths = Set(
            (project.sessions ?? []).compactMap { $0.taskFolderPath }
        )

        var importedCount = 0

        // Scan for task folders
        let taskFolders = findTaskFolders(in: tasksDir)

        for taskFolder in taskFolders {
            // Skip if session already exists for this task folder
            guard !existingTaskPaths.contains(taskFolder.path) else {
                continue
            }

            // Read and parse the TASK.md
            guard let taskContent = taskFolderService.readTask(at: taskFolder) else {
                continue
            }

            // Create a new session linked to this task
            let session = Session(
                name: taskContent.title ?? taskFolder.lastPathComponent,
                projectPath: project.path,
                userNamed: true
            )
            session.sessionDescription = taskContent.description
            session.taskFolderPath = taskFolder.path
            session.project = project

            // Mark as completed if task status is done
            if taskContent.isDone {
                session.isCompleted = true
                session.completedAt = Date()
            }

            // Try to link to a task group based on parent folder
            let parentName = taskFolder.deletingLastPathComponent().lastPathComponent
            if parentName != "tasks" {
                // Task is in a sub-project folder
                if let group = (project.taskGroups ?? []).first(where: {
                    taskFolderService.slugify($0.name) == parentName
                }) {
                    session.taskGroup = group
                }
            }

            modelContext.insert(session)
            importedCount += 1
            logger.info("Imported task: \(taskContent.title ?? "Unknown")")
        }

        if importedCount > 0 {
            do {
                try modelContext.save()
                logger.info("Imported \(importedCount) tasks for \(project.name)")
            } catch {
                logger.error("Failed to save imported tasks: \(error.localizedDescription)")
            }
        }

        return importedCount
    }

    /// Find all task folders (those with TASK.md) in a directory, recursively
    private func findTaskFolders(in directory: URL) -> [URL] {
        var taskFolders: [URL] = []

        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            return []
        }

        for item in contents {
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: item.path, isDirectory: &isDir),
                  isDir.boolValue else {
                continue
            }

            let taskFile = item.appendingPathComponent("TASK.md")
            if fileManager.fileExists(atPath: taskFile.path) {
                // This is a task folder
                taskFolders.append(item)
            } else {
                // Check if it's a sub-project folder (no number prefix)
                let name = item.lastPathComponent
                if !(name.first?.isNumber ?? false) {
                    // Recurse into sub-project folders
                    taskFolders.append(contentsOf: findTaskFolders(in: item))
                }
            }
        }

        return taskFolders
    }

    /// Check how many tasks would be imported (without actually importing)
    func countImportableTasks(for project: Project) -> Int {
        let tasksDir = taskFolderService.tasksDirectory(for: project.path)

        guard fileManager.fileExists(atPath: tasksDir.path) else {
            return 0
        }

        let existingTaskPaths = Set(
            (project.sessions ?? []).compactMap { $0.taskFolderPath }
        )

        let taskFolders = findTaskFolders(in: tasksDir)

        return taskFolders.filter { !existingTaskPaths.contains($0.path) }.count
    }
}
