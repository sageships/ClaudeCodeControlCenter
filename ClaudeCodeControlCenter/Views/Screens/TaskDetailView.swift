import SwiftUI

struct TaskDetailView: View {
    let task: WorkTask
    @EnvironmentObject var store: AppStore
    @State private var showPlanEditor = false
    @State private var editedPlan = ""
    @State private var logSearchText = ""
    
    var sessions: [Session] {
        store.getSessionsForWorkTask(task.id)
    }
    
    var latestSession: Session? {
        sessions.first
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                TaskHeaderSection(task: task)
                
                Divider()
                
                // Quick Actions
                QuickActionsSection(task: task)
                
                Divider()
                
                // Session Status
                if let session = latestSession {
                    SessionSection(session: session, task: task, showPlanEditor: $showPlanEditor, editedPlan: $editedPlan)
                } else {
                    StartSessionSection(task: task)
                }
                
                Divider()
                
                // Logs
                if let session = latestSession {
                    LogsSection(session: session, searchText: $logSearchText)
                }
                
                // Session History
                if sessions.count > 1 {
                    SessionHistorySection(sessions: Array(sessions.dropFirst()))
                }
            }
            .padding(24)
        }
        .navigationTitle(task.title)
        .sheet(isPresented: $showPlanEditor) {
            PlanEditorSheet(plan: $editedPlan, task: task)
        }
    }
}

struct TaskHeaderSection: View {
    let task: WorkTask
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(task.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                Text(task.mode.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(task.mode == .planFirst ? Color.blue.opacity(0.2) : Color.orange.opacity(0.2))
                    .cornerRadius(6)
            }
            
            // Task description
            if !task.description.isEmpty {
                Text(task.description)
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding(.vertical, 4)
            }
            
            HStack(spacing: 16) {
                Label(task.branchName, systemImage: "arrow.branch")
                Label(task.baseBranch, systemImage: "arrow.triangle.branch")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            
            Text(task.worktreePath)
                .font(.caption)
                .foregroundColor(.secondary)
                .textSelection(.enabled)
        }
    }
}

struct QuickActionsSection: View {
    let task: WorkTask
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: { store.openInFinder(task.worktreePath) }) {
                Label("Finder", systemImage: "folder")
            }
            
            Button(action: { store.openInTerminal(task.worktreePath) }) {
                Label("Terminal", systemImage: "terminal")
            }
            
            Button(action: { store.openInEditor(task.worktreePath) }) {
                Label("Editor", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            
            Spacer()
            
            Button(role: .destructive, action: { deleteWorkTask() }) {
                Label("Delete", systemImage: "trash")
            }
        }
        .buttonStyle(.bordered)
    }
    
    private func deleteWorkTask() {
        Task {
            await store.deleteWorkTask(task, removeWorktree: true, deleteBranch: false)
        }
    }
}

struct StartSessionSection: View {
    let task: WorkTask
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.circle")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            Text("Ready to Start")
                .font(.headline)
            
            Text(task.mode == .planFirst
                 ? "Start the planner agent to create an implementation plan"
                 : "Start the agent in direct mode")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: { store.startSession(for: task) }) {
                Label(task.mode == .planFirst ? "Start Planner" : "Start Agent", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

struct SessionSection: View {
    let session: Session
    let task: WorkTask
    @EnvironmentObject var store: AppStore
    @Binding var showPlanEditor: Bool
    @Binding var editedPlan: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Current Session")
                    .font(.headline)
                Spacer()
                SessionStatusBadge(status: session.status)
            }
            
            // Session info
            HStack(spacing: 24) {
                if let startedAt = session.startedAt {
                    Label(startedAt.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                }
                if let pid = session.pid {
                    Label("PID: \(pid)", systemImage: "number")
                }
                if let lastAction = session.lastToolAction {
                    Label(lastAction, systemImage: "hammer")
                        .lineLimit(1)
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            // Status-specific actions
            switch session.status {
            case .awaitingApproval:
                AwaitingApprovalView(session: session, task: task, showPlanEditor: $showPlanEditor, editedPlan: $editedPlan)
            case .planning, .running:
                RunningView(session: session)
            case .blocked:
                BlockedView(session: session)
            case .queued:
                QueuedView()
            case .succeeded:
                SucceededView(task: task)
            case .failed:
                FailedView(session: session, task: task)
            case .stopped:
                StoppedView(task: task)
            }
        }
    }
}

struct AwaitingApprovalView: View {
    let session: Session
    let task: WorkTask
    @EnvironmentObject var store: AppStore
    @Binding var showPlanEditor: Bool
    @Binding var editedPlan: String
    
    var plan: String {
        if let planPath = session.planPath {
            return store.readPlanFile(at: planPath) ?? "No plan found"
        }
        return "No plan found"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Plan Ready for Review")
                .font(.subheadline)
                .fontWeight(.medium)
            
            // Plan preview
            GroupBox {
                ScrollView {
                    Text(plan)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 300)
            }
            
            HStack(spacing: 12) {
                Button(action: approvePlan) {
                    Label("Approve & Execute", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                
                Button(action: {
                    editedPlan = plan
                    showPlanEditor = true
                }) {
                    Label("Edit Plan", systemImage: "pencil")
                }
                .buttonStyle(.bordered)
                
                Button(role: .destructive, action: cancelPlan) {
                    Label("Cancel", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func approvePlan() {
        store.startExecutorSession(for: task, plan: plan)
    }
    
    private func cancelPlan() {
        store.stopSession(session)
    }
}

struct RunningView: View {
    let session: Session
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text(session.phase == .planner ? "Planner is working..." : "Executor is running...")
            Spacer()
            Button(action: { store.stopSession(session) }) {
                Label("Stop", systemImage: "stop.fill")
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

struct BlockedView: View {
    let session: Session
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
            Text("Session appears blocked (no activity)")
            Spacer()
            Button(action: { store.stopSession(session) }) {
                Label("Stop", systemImage: "stop.fill")
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
    }
}

struct QueuedView: View {
    var body: some View {
        HStack {
            Image(systemName: "clock")
                .foregroundColor(.gray)
            Text("Waiting in queue...")
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct SucceededView: View {
    let task: WorkTask
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("Session completed successfully")
            Spacer()
            Button(action: { store.startSession(for: task) }) {
                Label("Run Again", systemImage: "play.fill")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
}

struct FailedView: View {
    let session: Session
    let task: WorkTask
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        HStack {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
            VStack(alignment: .leading) {
                Text("Session failed")
                if let exitCode = session.exitCode {
                    Text("Exit code: \(exitCode)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Button(action: { store.startSession(for: task) }) {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }
}

struct StoppedView: View {
    let task: WorkTask
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        HStack {
            Image(systemName: "stop.circle.fill")
                .foregroundColor(.gray)
            Text("Session was stopped")
            Spacer()
            Button(action: { store.startSession(for: task) }) {
                Label("Start Again", systemImage: "play.fill")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct LogsSection: View {
    let session: Session
    @EnvironmentObject var store: AppStore
    @Binding var searchText: String
    @State private var logContent = ""
    
    let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    
    var filteredLog: String {
        if searchText.isEmpty {
            return logContent
        }
        return logContent
            .components(separatedBy: "\n")
            .filter { $0.localizedCaseInsensitiveContains(searchText) }
            .joined(separator: "\n")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Logs")
                    .font(.headline)
                Spacer()
                TextField("Search logs...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
            }
            
            ScrollView {
                Text(filteredLog)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 300)
            .padding(8)
            .background(Color.black.opacity(0.8))
            .foregroundColor(.green)
            .cornerRadius(8)
        }
        .onAppear { loadLog() }
        .onReceive(timer) { _ in
            if session.status.isActive {
                loadLog()
            }
        }
    }
    
    private func loadLog() {
        logContent = store.readLogFile(at: session.logPath)
    }
}

struct SessionHistorySection: View {
    let sessions: [Session]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session History")
                .font(.headline)
            
            ForEach(sessions) { session in
                HStack {
                    Text(session.phase.rawValue.capitalized)
                        .font(.caption)
                    SessionStatusBadge(status: session.status)
                    Spacer()
                    if let startedAt = session.startedAt {
                        Text(startedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

struct PlanEditorSheet: View {
    @Binding var plan: String
    let task: WorkTask
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Edit Plan")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            
            TextEditor(text: $plan)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 400)
            
            HStack {
                Spacer()
                Button(action: saveAndApprove) {
                    Label("Save & Execute", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding()
        .frame(width: 800, height: 600)
    }
    
    private func saveAndApprove() {
        store.startExecutorSession(for: task, plan: plan)
        dismiss()
    }
}

