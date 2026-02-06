import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var store: AppStore
    @Binding var showNewWorkspace: Bool
    @State private var showSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            List(selection: $store.selectedWorkspaceId) {
                Section {
                    ForEach(store.workspaces) { workspace in
                        WorkspaceRow(workspace: workspace)
                            .tag(workspace.id)
                    }
                    .onDelete(perform: deleteWorkspaces)
                } header: {
                    HStack {
                        Text("Workspaces")
                        Spacer()
                        Button(action: { showNewWorkspace = true }) {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.sidebar)
            
            Divider()
            
            // Settings button at bottom
            Button(action: { showSettings = true }) {
                HStack {
                    Image(systemName: "gear")
                    Text("Settings")
                    Spacer()
                    Text("⌘,")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: .command)
        }
        .navigationTitle("Control Center")
        .frame(minWidth: 200)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
    
    private func deleteWorkspaces(at offsets: IndexSet) {
        for index in offsets {
            store.deleteWorkspace(store.workspaces[index])
        }
    }
}

struct WorkspaceRow: View {
    let workspace: Workspace
    @EnvironmentObject var store: AppStore
    
    var taskCount: Int {
        store.tasks.filter { $0.workspaceId == workspace.id }.count
    }
    
    var body: some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(workspace.name)
                    .font(.headline)
                Text("\(taskCount) tasks")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

