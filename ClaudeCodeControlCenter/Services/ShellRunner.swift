import Foundation

enum ShellError: LocalizedError {
    case processError(String)
    case commandFailed(exitCode: Int32, stderr: String)
    
    var errorDescription: String? {
        switch self {
        case .processError(let message):
            return "Process error: \(message)"
        case .commandFailed(let exitCode, let stderr):
            return "Command failed with exit code \(exitCode): \(stderr)"
        }
    }
}

/// A result from running a shell command
struct ShellResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
    
    var succeeded: Bool { exitCode == 0 }
}

/// Handles process execution with streaming output
@MainActor
class ShellRunner: ObservableObject {
    private var runningProcesses: [UUID: Process] = [:]
    
    /// Run a command synchronously and return the result
    func run(
        _ arguments: [String],
        workingDirectory: String? = nil,
        environment: [String: String]? = nil
    ) async throws -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = arguments
        
        if let workingDirectory = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        }
        
        if let environment = environment {
            var env = ProcessInfo.processInfo.environment
            for (key, value) in environment {
                env[key] = value
            }
            process.environment = env
        }
        
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw ShellError.processError(error.localizedDescription)
        }
        
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        
        return ShellResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)
    }
    
    /// Run a command with streaming output to a log file
    func runWithStreaming(
        id: UUID,
        arguments: [String],
        workingDirectory: String? = nil,
        environment: [String: String]? = nil,
        logPath: String,
        onOutput: @escaping (String) -> Void,
        onComplete: @escaping (Int32) -> Void
    ) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = arguments
        
        if let workingDirectory = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        }
        
        if let environment = environment {
            var env = ProcessInfo.processInfo.environment
            for (key, value) in environment {
                env[key] = value
            }
            process.environment = env
        }
        
        // Create log file
        let logURL = URL(fileURLWithPath: logPath)
        let logDir = logURL.deletingLastPathComponent()
        
        // Ensure directory exists
        try FileManager.default.createDirectory(
            at: logDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Create the log file - use Data write which is more reliable
        let emptyData = Data()
        try emptyData.write(to: logURL)
        
        let logHandle = try FileHandle(forWritingTo: logURL)
        
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        // Handle stdout
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                try? logHandle.write(contentsOf: data)
                if let str = String(data: data, encoding: .utf8) {
                    Task { @MainActor in
                        onOutput(str)
                    }
                }
            }
        }
        
        // Handle stderr
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                try? logHandle.write(contentsOf: data)
                if let str = String(data: data, encoding: .utf8) {
                    Task { @MainActor in
                        onOutput(str)
                    }
                }
            }
        }
        
        process.terminationHandler = { [weak self] proc in
            try? logHandle.close()
            Task { @MainActor in
                self?.runningProcesses.removeValue(forKey: id)
                onComplete(proc.terminationStatus)
            }
        }
        
        try process.run()
        runningProcesses[id] = process
    }
    
    /// Stop a running process
    func stop(id: UUID) {
        guard let process = runningProcesses[id] else { return }
        process.terminate()
        runningProcesses.removeValue(forKey: id)
    }
    
    /// Get PID of a running process
    func getPid(id: UUID) -> Int32? {
        return runningProcesses[id]?.processIdentifier
    }
    
    /// Check if a process is still running
    func isRunning(id: UUID) -> Bool {
        guard let process = runningProcesses[id] else { return false }
        return process.isRunning
    }
}
