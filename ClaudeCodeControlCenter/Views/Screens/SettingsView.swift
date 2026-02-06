import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @State private var saved = false
    
    var body: some View {
        VStack(spacing: 0) {
            TabView {
                GeneralSettingsTab()
                    .tabItem {
                        Label("General", systemImage: "gear")
                    }
                
                AgentSettingsTab()
                    .tabItem {
                        Label("Agent", systemImage: "cpu")
                    }
                
                PromptsSettingsTab()
                    .tabItem {
                        Label("Prompts", systemImage: "text.quote")
                    }
            }
            
            Divider()
            
            // Footer with Save/Close buttons
            HStack {
                if saved {
                    Label("Saved!", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .transition(.opacity)
                }
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Button("Save & Close") {
                    store.saveSettings()
                    saved = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
            }
            .padding()
        }
        .frame(width: 600, height: 550)
    }
}

struct GeneralSettingsTab: View {
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        Form {
            Section {
                TextField("Default Worktrees Root", text: $store.settings.defaultWorktreesRoot)
                    .textFieldStyle(.roundedBorder)
            } header: {
                Text("Paths")
            } footer: {
                Text("Default location for creating git worktrees")
            }
            
            Section {
                TextField("Editor Command", text: $store.settings.editorCommand)
                    .textFieldStyle(.roundedBorder)
            } header: {
                Text("Editor")
            } footer: {
                Text("App name to open worktrees (e.g., Cursor, Visual Studio Code)")
            }
            
            Section {
                Stepper("Max Concurrent Sessions: \(store.settings.maxConcurrentSessions)",
                       value: $store.settings.maxConcurrentSessions, in: 1...10)
            } header: {
                Text("Concurrency")
            } footer: {
                Text("Maximum number of agent sessions that can run simultaneously")
            }
            
            Section {
                Stepper("Blocked Timeout: \(store.settings.blockedTimeoutMinutes) minutes",
                       value: $store.settings.blockedTimeoutMinutes, in: 1...30)
            } header: {
                Text("Timeouts")
            } footer: {
                Text("Mark session as blocked if no output for this duration")
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: store.settings) { _, _ in
            store.saveSettings()
        }
    }
}

struct AgentSettingsTab: View {
    @EnvironmentObject var store: AppStore
    
    private var isDefaultCommand: Bool {
        store.settings.agentCommandTemplate.contains("Configure your agent command")
    }
    
    var body: some View {
        Form {
            // Warning if using default command
            if isDefaultCommand {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Configure your AI agent command below to get started")
                            .foregroundColor(.orange)
                    }
                    .padding(.vertical, 8)
                }
            }
            
            Section {
                TextField("Command Template", text: $store.settings.agentCommandTemplate, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                    .font(.system(.body, design: .monospaced))
            } header: {
                Text("Agent Command Template")
            } footer: {
                Text("Placeholders: {{worktree}}, {{mode}}, {{promptFile}}, {{nonInteractiveFlag}}")
            }
            
            Section {
                TextField("Non-Interactive Flag", text: $store.settings.nonInteractiveFlag)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            } header: {
                Text("Executor Mode")
            } footer: {
                Text("Flag added for executor phase (leave empty if not needed)")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Example Configurations")
                        .font(.headline)
                    
                    AgentPresetButton(
                        name: "Claude Code",
                        command: "claude --print \"$(cat '{{promptFile}}')\" {{nonInteractiveFlag}}",
                        flag: "--dangerously-skip-permissions",
                        store: store
                    )
                    
                    AgentPresetButton(
                        name: "Aider",
                        command: "aider --yes-always --message-file '{{promptFile}}'",
                        flag: "",
                        store: store
                    )
                    
                    AgentPresetButton(
                        name: "Test (Echo)",
                        command: "echo 'Agent running in {{mode}} mode at {{worktree}}' && cat '{{promptFile}}' && sleep 2 && echo 'Done!'",
                        flag: "",
                        store: store
                    )
                }
            } header: {
                Text("Presets")
            } footer: {
                Text("Click to apply a preset configuration")
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: store.settings) { _, _ in
            store.saveSettings()
        }
    }
}

struct AgentPresetButton: View {
    let name: String
    let command: String
    let flag: String
    let store: AppStore
    
    var body: some View {
        Button {
            store.settings.agentCommandTemplate = command
            store.settings.nonInteractiveFlag = flag
            store.saveSettings()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .fontWeight(.medium)
                    Text(command)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "arrow.right.circle")
                    .foregroundColor(.accentColor)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

struct PromptsSettingsTab: View {
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        Form {
            Section {
                TextEditor(text: $store.settings.plannerPromptTemplate)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 150)
            } header: {
                Text("Planner Prompt")
            } footer: {
                Text("Instructions sent to the agent during planning phase")
            }
            
            Section {
                TextEditor(text: $store.settings.executorPromptTemplate)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 150)
            } header: {
                Text("Executor Prompt")
            } footer: {
                Text("Instructions sent to the agent during execution phase")
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: store.settings) { _, _ in
            store.saveSettings()
        }
    }
}

