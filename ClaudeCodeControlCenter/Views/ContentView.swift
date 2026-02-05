import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: AppStore
    @State private var showNewWorkspace = false
    @State private var showNewTask = false
    
    var body: some View {
        NavigationSplitView {
            // Sidebar - Workspaces
            SidebarView(showNewWorkspace: $showNewWorkspace)
        } content: {
            // Task List
            if store.selectedWorkspace != nil {
                TaskListView(showNewTask: $showNewTask)
            } else {
                EmptyStateView(
                    icon: "folder.badge.gearshape",
                    title: "No Workspace Selected",
                    message: "Select or create a workspace to get started"
                )
            }
        } detail: {
            // Task Detail
            if let task = store.selectedTask {
                TaskDetailView(task: task)
            } else {
                EmptyStateView(
                    icon: "checklist",
                    title: "No Task Selected",
                    message: "Select a task to view details and manage sessions"
                )
            }
        }
        .sheet(isPresented: $showNewWorkspace) {
            NewWorkspaceSheet()
        }
        .sheet(isPresented: $showNewTask) {
            if let workspace = store.selectedWorkspace {
                NewTaskSheet(workspace: workspace)
            }
        }
        .alert("Error", isPresented: .init(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

