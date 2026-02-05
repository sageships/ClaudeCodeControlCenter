import Foundation
import SwiftUI

/// Main application store managing all state
@MainActor
class AppStore: ObservableObject {
    // MARK: - Published State
    @Published var workspaces: [Workspace] = []
    @Published var tasks: [WorkTask] = []
    @Published var sessions: [Session] = []
    @Published var settings: AppSettings = .default
    
    @Published var selectedWorkspaceId: UUID?
    @Published var selectedTaskId: UUID?
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Services
    private let persistence = PersistenceService()
    let shell = ShellRunner()
    lazy var git = GitService(shell: shell)
    
    // MARK: - Session Management
    private var blockedCheckTimer: Timer?
    
    // MARK: - Computed Properties
    
    var selectedWorkspace: Workspace? {
        workspaces.first { $0.id == selectedWorkspaceId }
    }
    
    var selectedTask: WorkTask? {
        tasks.first { $0.id == selectedTaskId }
    }
    
    var tasksForSelectedWorkspace: [WorkTask] {
        guard let workspaceId = selectedWorkspaceId else { return [] }
        return tasks.filter { $0.workspaceId == workspaceId }
    }
    
    var runningSessionsCount: Int {
        sessions.filter { $0.status.isActive }.count
    }
    
    var canStartNewSession: Bool {
        runningSessionsCount < settings.maxConcurrentSessions
    }
    
    // MARK: - Initialization
    
    init() {
        loadData()
        startBlockedCheckTimer()
    }
    
    // MARK: - Persistence
    
    private func loadData() {
        do {
            if persistence.fileExists("workspaces.json") {
                workspaces = try persistence.load([Workspace].self, from: "workspaces.json")
            }
            if persistence.fileExists("tasks.json") {
                tasks = try persistence.load([WorkTask].self, from: "tasks.json")
            }
            if persistence.fileExists("sessions.json") {
                sessions = try persistence.load([Session].self, from: "sessions.json")
            }
            if persistence.fileExists("settings.json") {
                settings = try persistence.load(AppSettings.self, from: "settings.json")
            }
        } catch {
            print("Error loading data: \(error)")
        }
    }
    
    private func saveWorkspaces() {
        try? persistence.save(workspaces, to: "workspaces.json")
    }
    
    private func saveTasks() {
        try? persistence.save(tasks, to: "tasks.json")
    }
    
    private func saveSessions() {
        try? persistence.save(sessions, to: "sessions.json")
    }
    
    func saveSettings() {
        try? persistence.save(settings, to: "settings.json")
    }
    
    // MARK: - Workspace Management
    
    func addWorkspace(_ workspace: Workspace) {
        workspaces.append(workspace)
        saveWorkspaces()
    }
    
    func updateWorkspace(_ workspace: Workspace) {
        if let index = workspaces.firstIndex(where: { $0.id == workspace.id }) {
            workspaces[index] = workspace
            saveWorkspaces()
        }
    }
    
    func deleteWorkspace(_ workspace: Workspace) {
        // Delete all tasks for this workspace
        let tasksToDelete = tasks.filter { $0.workspaceId == workspace.id }
        for task in tasksToDelete {
            Task {
                await deleteWorkTask(task, removeWorktree: true, deleteBranch: false)
            }
        }
        workspaces.removeAll { $0.id == workspace.id }
        saveWorkspaces()
    }
    
    // MARK: - Task Management
    
    func createWorkTask(
        title: String,
        workspace: Workspace,
        baseBranch: String,
        branchName: String,
        mode: TaskMode,
        agentCommandTemplate: String? = nil
    ) async throws {
        isLoading = true
        defer { isLoading = false }
        
        // Build worktree path
        let worktreePath = "\(workspace.worktreesRoot)/\(branchName)"
        
        // Create git worktree
        try await git.createWorktree(
            repoPath: workspace.repoPath,
            worktreePath: worktreePath,
            branchName: branchName,
            baseBranch: baseBranch
        )
        
        // Create task
        let task = WorkTask(
            title: title,
            workspaceId: workspace.id,
            baseBranch: baseBranch,
            branchName: branchName,
            worktreePath: worktreePath,
            mode: mode,
            agentCommandTemplate: agentCommandTemplate
        )
        
        tasks.append(task)
        saveTasks()
    }
    
    func deleteWorkTask(_ task: WorkTask, removeWorktree: Bool, deleteBranch: Bool) async {
        // Stop any running sessions
        let taskSessions = sessions.filter { $0.taskId == task.id }
        for session in taskSessions {
            if session.status.isActive {
                stopSession(session)
            }
        }
        
        // Remove sessions
        sessions.removeAll { $0.taskId == task.id }
        saveSessions()
        
        // Remove worktree if requested
        if removeWorktree, let workspace = workspaces.first(where: { $0.id == task.workspaceId }) {
            try? await git.removeWorktree(
                repoPath: workspace.repoPath,
                worktreePath: task.worktreePath,
                deleteBranch: deleteBranch
            )
        }
        
        tasks.removeAll { $0.id == task.id }
        saveTasks()
    }
    
    // MARK: - Session Management
    
    func startSession(for task: WorkTask) {
        let phase: SessionPhase = task.mode == .planFirst ? .planner : .direct
        let status: SessionStatus = canStartNewSession ? (phase == .planner ? .planning : .running) : .queued
        
        // Create log path
        let logDir = AppSettings.logsDirectory.appendingPathComponent(task.id.uuidString)
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        let logPath = logDir.appendingPathComponent("\(UUID().uuidString).log").path
        
        var session = Session(
            taskId: task.id,
            phase: phase,
            status: status,
            logPath: logPath
        )
        
        if phase == .planner {
            session.planPath = "\(task.worktreePath)/PLAN.md"
        }
        
        sessions.append(session)
        saveSessions()
        
        if status != .queued {
            runSession(session)
        }
    }
    
    func startExecutorSession(for task: WorkTask, plan: String) {
        let status: SessionStatus = canStartNewSession ? .running : .queued
        
        // Create log path
        let logDir = AppSettings.logsDirectory.appendingPathComponent(task.id.uuidString)
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        let logPath = logDir.appendingPathComponent("\(UUID().uuidString).log").path
        
        let session = Session(
            taskId: task.id,
            phase: .executor,
            status: status,
            logPath: logPath,
            planPath: "\(task.worktreePath)/PLAN.md"
        )
        
        // Save plan to file
        try? plan.write(toFile: "\(task.worktreePath)/PLAN.md", atomically: true, encoding: .utf8)
        
        sessions.append(session)
        saveSessions()
        
        if status != .queued {
            runSession(session)
        }
    }
    
    private func runSession(_ session: Session) {
        guard let task = tasks.first(where: { $0.id == session.taskId }) else { return }
        
        // Build command
        let template = task.agentCommandTemplate ?? settings.agentCommandTemplate
        let promptTemplate = session.phase == .planner ? settings.plannerPromptTemplate : settings.executorPromptTemplate
        
        // Create prompt file
        let promptPath = "\(task.worktreePath)/.agent-prompt.txt"
        try? promptTemplate.write(toFile: promptPath, atomically: true, encoding: .utf8)
        
        // Replace placeholders
        var command = template
            .replacingOccurrences(of: "{{worktree}}", with: task.worktreePath)
            .replacingOccurrences(of: "{{promptFile}}", with: promptPath)
            .replacingOccurrences(of: "{{mode}}", with: session.phase.rawValue)
        
        // Add non-interactive flag for executor
        if session.phase == .executor && !settings.nonInteractiveFlag.isEmpty {
            command = command.replacingOccurrences(of: "{{nonInteractiveFlag}}", with: settings.nonInteractiveFlag)
        } else {
            command = command.replacingOccurrences(of: "{{nonInteractiveFlag}}", with: "")
        }
        
        // Update session state
        updateSession(session.id) { s in
            s.startedAt = Date()
            s.lastActivityAt = Date()
        }
        
        // Run the command
        let arguments = command.components(separatedBy: " ").filter { !$0.isEmpty }
        
        do {
            try shell.runWithStreaming(
                id: session.id,
                arguments: arguments,
                workingDirectory: task.worktreePath,
                logPath: session.logPath,
                onOutput: { [weak self] output in
                    self?.handleSessionOutput(session.id, output: output)
                },
                onComplete: { [weak self] exitCode in
                    self?.handleSessionComplete(session.id, exitCode: exitCode)
                }
            )
            
            // Update PID
            if let pid = shell.getPid(id: session.id) {
                updateSession(session.id) { s in
                    s.pid = pid
                }
            }
        } catch {
            updateSession(session.id) { s in
                s.status = .failed
                s.endedAt = Date()
            }
            self.errorMessage = "Failed to start session: \(error.localizedDescription)"
        }
    }
    
    private func handleSessionOutput(_ sessionId: UUID, output: String) {
        updateSession(sessionId) { s in
            s.lastActivityAt = Date()
            
            // Try to parse tool actions from output
            let patterns = ["Running:", "Executing:", "tool:", "bash:", "git:", "command:"]
            for pattern in patterns {
                if let range = output.range(of: pattern, options: .caseInsensitive) {
                    let actionStart = output[range.upperBound...]
                    let action = actionStart.prefix(100).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !action.isEmpty {
                        s.lastToolAction = String(action.prefix(80))
                    }
                }
            }
        }
    }
    
    private func handleSessionComplete(_ sessionId: UUID, exitCode: Int32) {
        guard let session = sessions.first(where: { $0.id == sessionId }) else { return }
        
        updateSession(sessionId) { s in
            s.exitCode = exitCode
            s.endedAt = Date()
            
            if exitCode == 0 {
                if s.phase == .planner {
                    s.status = .awaitingApproval
                } else {
                    s.status = .succeeded
                }
            } else {
                s.status = .failed
            }
        }
        
        // Start next queued session
        startNextQueuedSession()
    }
    
    func stopSession(_ session: Session) {
        shell.stop(id: session.id)
        updateSession(session.id) { s in
            s.status = .stopped
            s.endedAt = Date()
        }
        startNextQueuedSession()
    }
    
    private func startNextQueuedSession() {
        guard canStartNewSession else { return }
        
        if let queuedSession = sessions.first(where: { $0.status == .queued }) {
            updateSession(queuedSession.id) { s in
                s.status = s.phase == .planner ? .planning : .running
            }
            if let session = sessions.first(where: { $0.id == queuedSession.id }) {
                runSession(session)
            }
        }
    }
    
    private func updateSession(_ id: UUID, update: (inout Session) -> Void) {
        if let index = sessions.firstIndex(where: { $0.id == id }) {
            update(&sessions[index])
            saveSessions()
        }
    }
    
    // MARK: - Blocked Detection
    
    private func startBlockedCheckTimer() {
        blockedCheckTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForBlockedSessions()
            }
        }
    }
    
    private func checkForBlockedSessions() {
        let timeout = TimeInterval(settings.blockedTimeoutMinutes * 60)
        let now = Date()
        
        for session in sessions where session.status.isActive {
            if let lastActivity = session.lastActivityAt,
               now.timeIntervalSince(lastActivity) > timeout,
               shell.isRunning(id: session.id) {
                updateSession(session.id) { s in
                    s.status = .blocked
                }
            }
        }
    }
    
    // MARK: - Utilities
    
    func getSessionsForWorkTask(_ taskId: UUID) -> [Session] {
        sessions.filter { $0.taskId == taskId }.sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) }
    }
    
    func getLatestSessionForWorkTask(_ taskId: UUID) -> Session? {
        getSessionsForWorkTask(taskId).first
    }
    
    func readLogFile(at path: String, tail: Int = 500) -> String {
        guard let data = FileManager.default.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else {
            return ""
        }
        
        let lines = content.components(separatedBy: "\n")
        let tailLines = lines.suffix(tail)
        return tailLines.joined(separator: "\n")
    }
    
    func readPlanFile(at path: String) -> String? {
        guard let data = FileManager.default.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }
        return content
    }
    
    func openInFinder(_ path: String) {
        let expandedPath = (path as NSString).expandingTildeInPath
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: expandedPath)
    }
    
    func openInTerminal(_ path: String) {
        let expandedPath = (path as NSString).expandingTildeInPath
        let script = """
        tell application "Terminal"
            do script "cd '\(expandedPath)'"
            activate
        end tell
        """
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
        }
    }
    
    func openInEditor(_ path: String) {
        let expandedPath = (path as NSString).expandingTildeInPath
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        
        if !settings.editorCommand.isEmpty {
            process.arguments = ["-a", settings.editorCommand, expandedPath]
        } else {
            process.arguments = [expandedPath]
        }
        
        try? process.run()
    }
}
