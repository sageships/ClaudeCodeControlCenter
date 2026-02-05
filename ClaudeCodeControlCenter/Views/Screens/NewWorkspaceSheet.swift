import SwiftUI

struct NewWorkspaceSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var repoPath = ""
    @State private var defaultBaseBranch = "main"
    @State private var worktreesRoot = ""
    @State private var isValidating = false
    @State private var validationError: String?
    
    var canSave: Bool {
        !name.isEmpty && !repoPath.isEmpty && !defaultBaseBranch.isEmpty && !worktreesRoot.isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Workspace")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()
            
            Divider()
            
            // Form
            Form {
                Section {
                    TextField("Workspace Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("Name")
                }
                
                Section {
                    HStack {
                        TextField("Repository Path", text: $repoPath)
                            .textFieldStyle(.roundedBorder)
                        Button("Browse...") {
                            browseForRepo()
                        }
                    }
                    if let error = validationError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                } header: {
                    Text("Git Repository")
                } footer: {
                    Text("Select a folder containing a git repository")
                }
                
                Section {
                    TextField("Default Base Branch", text: $defaultBaseBranch)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("Base Branch")
                } footer: {
                    Text("Branch to base new worktrees on (e.g., main, master, develop)")
                }
                
                Section {
                    HStack {
                        TextField("Worktrees Root", text: $worktreesRoot)
                            .textFieldStyle(.roundedBorder)
                        Button("Browse...") {
                            browseForWorktreesRoot()
                        }
                    }
                } header: {
                    Text("Worktrees Location")
                } footer: {
                    Text("Folder where git worktrees will be created")
                }
            }
            .formStyle(.grouped)
            .padding()
            
            Divider()
            
            // Footer
            HStack {
                Spacer()
                Button(action: save) {
                    if isValidating {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Text("Add Workspace")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave || isValidating)
                .keyboardShortcut(.return)
            }
            .padding()
        }
        .frame(width: 500, height: 500)
        .onAppear {
            worktreesRoot = store.settings.defaultWorktreesRoot
        }
    }
    
    private func browseForRepo() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a git repository folder"
        
        if panel.runModal() == .OK, let url = panel.url {
            repoPath = url.path
            if name.isEmpty {
                name = url.lastPathComponent
            }
            validateRepo()
        }
    }
    
    private func browseForWorktreesRoot() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = "Select folder for worktrees"
        
        if panel.runModal() == .OK, let url = panel.url {
            worktreesRoot = url.path
        }
    }
    
    private func validateRepo() {
        isValidating = true
        validationError = nil
        
        Task {
            let isValid = await store.git.isValidRepository(repoPath)
            await MainActor.run {
                isValidating = false
                if !isValid {
                    validationError = "This doesn't appear to be a git repository"
                }
            }
        }
    }
    
    private func save() {
        let workspace = Workspace(
            name: name,
            repoPath: repoPath,
            defaultBaseBranch: defaultBaseBranch,
            worktreesRoot: worktreesRoot
        )
        store.addWorkspace(workspace)
        store.selectedWorkspaceId = workspace.id
        dismiss()
    }
}

