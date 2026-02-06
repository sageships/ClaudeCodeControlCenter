import SwiftUI

struct NewTaskSheet: View {
    let workspace: Workspace
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    
    @State private var title = ""
    @State private var description = ""  // What to build
    @State private var baseBranch = ""
    @State private var branchName = ""
    @State private var branchNameManuallyEdited = false  // Track if user manually edited
    @State private var mode: TaskMode = .planFirst
    @State private var useCustomCommand = false
    @State private var customCommand = ""
    
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    var canCreate: Bool {
        !title.isEmpty && !description.isEmpty && !baseBranch.isEmpty && !branchName.isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Task")
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
                    TextField("Task Title", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: title) { _, newValue in
                            // Only auto-update branch name if user hasn't manually edited it
                            if !branchNameManuallyEdited {
                                branchName = WorkTask.suggestBranchName(from: newValue)
                            }
                        }
                } header: {
                    Text("Title")
                } footer: {
                    Text("Short name for this task")
                }
                
                Section {
                    TextEditor(text: $description)
                        .font(.body)
                        .frame(minHeight: 100)
                        .overlay(
                            Group {
                                if description.isEmpty {
                                    Text("Describe what you want to build in detail...")
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 4)
                                        .padding(.top, 8)
                                        .allowsHitTesting(false)
                                }
                            },
                            alignment: .topLeading
                        )
                } header: {
                    HStack {
                        Text("Description")
                        Text("*").foregroundColor(.red)
                    }
                } footer: {
                    Text("Be specific! This is what Claude will use to understand the task.")
                }
                
                Section {
                    TextField("Base Branch", text: $baseBranch)
                        .textFieldStyle(.roundedBorder)
                } header: {
                    Text("Base Branch")
                } footer: {
                    Text("Branch to create the worktree from (e.g., origin/main)")
                }
                
                Section {
                    HStack {
                        TextField("Branch Name", text: $branchName)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: branchName) { oldValue, newValue in
                                // Mark as manually edited if different from auto-suggestion
                                let suggested = WorkTask.suggestBranchName(from: title)
                                if newValue != suggested && !newValue.isEmpty {
                                    branchNameManuallyEdited = true
                                }
                            }
                        
                        // Reset button to regenerate from title
                        if branchNameManuallyEdited {
                            Button {
                                branchNameManuallyEdited = false
                                branchName = WorkTask.suggestBranchName(from: title)
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Reset to auto-generated name")
                        }
                    }
                } header: {
                    Text("New Branch Name")
                } footer: {
                    Text("A new branch will be created with this name")
                }
                
                Section {
                    Picker("Mode", selection: $mode) {
                        ForEach(TaskMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Execution Mode")
                } footer: {
                    if mode == .planFirst {
                        Text("Plan First: Agent creates a plan, you approve, then it executes")
                    } else {
                        Text("Direct: Agent runs immediately without planning phase")
                    }
                }
                
                Section {
                    Toggle("Use custom agent command", isOn: $useCustomCommand)
                    
                    if useCustomCommand {
                        TextField("Command template", text: $customCommand)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                } header: {
                    Text("Agent Command")
                } footer: {
                    Text("Placeholders: {{worktree}}, {{mode}}, {{promptFile}}, {{nonInteractiveFlag}}")
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .padding()
            
            Divider()
            
            // Footer
            HStack {
                // Preview path
                VStack(alignment: .leading) {
                    Text("Worktree path:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(workspace.worktreesRoot)/\(branchName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: create) {
                    if isCreating {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Text("Create Task")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canCreate || isCreating)
                .keyboardShortcut(.return)
            }
            .padding()
        }
        .frame(width: 550, height: 750)
        .onAppear {
            baseBranch = workspace.defaultBaseBranch
        }
    }
    
    private func create() {
        isCreating = true
        errorMessage = nil
        
        Task {
            do {
                try await store.createWorkTask(
                    title: title,
                    description: description,
                    workspace: workspace,
                    baseBranch: baseBranch,
                    branchName: branchName,
                    mode: mode,
                    agentCommandTemplate: useCustomCommand ? customCommand : nil
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

