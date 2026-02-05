import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    
    var body: some View {
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
        .frame(width: 600, height: 500)
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
    
    var body: some View {
        Form {
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
                Text("Built-in Test Agent")
                    .font(.headline)
                Text("For testing, use this echo agent command:")
                    .foregroundColor(.secondary)
                
                GroupBox {
                    Text("echo 'Agent running in {{mode}} mode at {{worktree}}' && sleep 3 && echo 'Done!'")
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            } header: {
                Text("Testing")
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: store.settings) { _, _ in
            store.saveSettings()
        }
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

