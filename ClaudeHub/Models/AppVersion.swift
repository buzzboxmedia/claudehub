import Foundation

struct AppVersion {
    // Version from git tags (e.g., "1.0.0" or "1.0.0-3-gbe2d2ec")
    static var version: String {
        getGitVersion() ?? "dev"
    }

    // Short commit hash
    static var buildHash: String {
        getGitHash() ?? "unknown"
    }

    private static let gitDir: URL? = {
        let possibleDirs = [
            NSHomeDirectory() + "/Code/claudehub",
            NSHomeDirectory() + "/code/claudehub",
            FileManager.default.currentDirectoryPath
        ]
        for dir in possibleDirs {
            if FileManager.default.fileExists(atPath: dir + "/.git") {
                return URL(fileURLWithPath: dir)
            }
        }
        return nil
    }()

    private static func runGit(_ args: [String]) -> String? {
        guard let dir = gitDir else { return nil }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = args
        task.currentDirectoryURL = dir

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !output.isEmpty {
                return output
            }
        } catch {}

        return nil
    }

    private static func getGitVersion() -> String? {
        // Use git describe to get version from tags
        // Format: v1.0.0 or v1.0.0-5-gbe2d2ec (5 commits after tag)
        if let describe = runGit(["describe", "--tags", "--always"]) {
            // Remove leading "v" if present
            if describe.hasPrefix("v") {
                return String(describe.dropFirst())
            }
            return describe
        }
        return nil
    }

    private static func getGitHash() -> String? {
        runGit(["rev-parse", "--short", "HEAD"])
    }
}
