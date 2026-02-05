import SwiftUI

struct TaskListView: View {
    @EnvironmentObject var store: AppStore
    @Binding var showNewTask: Bool
    
    var body: some View {
        List(selection: $store.selectedTaskId) {
            ForEach(store.tasksForSelectedWorkspace) { task in
                TaskRow(task: task)
                    .tag(task.id)
            }
        }
        .listStyle(.inset)
        .navigationTitle(store.selectedWorkspace?.name ?? "Tasks")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showNewTask = true }) {
                    Label("New Task", systemImage: "plus")
                }
            }
        }
        .overlay {
            if store.tasksForSelectedWorkspace.isEmpty {
                EmptyTasksView(showNewTask: $showNewTask)
            }
        }
        .frame(minWidth: 300)
    }
}

struct TaskRow: View {
    let task: WorkTask
    @EnvironmentObject var store: AppStore
    
    var latestSession: Session? {
        store.getLatestSessionForWorkTask(task.id)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)
                HStack(spacing: 8) {
                    Label(task.branchName, systemImage: "arrow.branch")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(task.mode.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(task.mode == .planFirst ? Color.blue.opacity(0.2) : Color.orange.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            if let session = latestSession {
                SessionStatusBadge(status: session.status)
            }
        }
        .padding(.vertical, 8)
        .contextMenu {
            Button(action: { store.openInFinder(task.worktreePath) }) {
                Label("Open in Finder", systemImage: "folder")
            }
            Button(action: { store.openInTerminal(task.worktreePath) }) {
                Label("Open Terminal", systemImage: "terminal")
            }
            Button(action: { store.openInEditor(task.worktreePath) }) {
                Label("Open in Editor", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            Divider()
            Button(role: .destructive, action: { deleteWorkTask() }) {
                Label("Delete Task", systemImage: "trash")
            }
        }
    }
    
    private func deleteWorkTask() {
        Task {
            await store.deleteWorkTask(task, removeWorktree: true, deleteBranch: false)
        }
    }
}

struct SessionStatusBadge: View {
    let status: SessionStatus
    
    var color: Color {
        switch status {
        case .planning, .running: return .blue
        case .awaitingApproval: return .orange
        case .queued: return .gray
        case .blocked: return .yellow
        case .succeeded: return .green
        case .failed: return .red
        case .stopped: return .gray
        }
    }
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(6)
    }
}

struct EmptyTasksView: View {
    @Binding var showNewTask: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No Tasks Yet")
                .font(.headline)
            Text("Create a task to start working with git worktrees and AI agents")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button(action: { showNewTask = true }) {
                Label("New Task", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

