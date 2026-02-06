import Foundation

struct AppSettings: Codable, Equatable {
    var agentCommandTemplate: String
    var plannerPromptTemplate: String
    var executorPromptTemplate: String
    var nonInteractiveFlag: String
    var blockedTimeoutMinutes: Int
    var maxConcurrentSessions: Int
    var defaultWorktreesRoot: String
    var editorCommand: String
    var terminalCommand: String
    
    static let `default` = AppSettings(
        // Default template - users should customize for their agent
        // Examples:
        //   Claude Code: claude --print "$(cat '{{promptFile}}')" {{nonInteractiveFlag}}
        //   Aider: aider --yes-always --message-file '{{promptFile}}'
        //   Cursor: cursor '{{worktree}}'
        agentCommandTemplate: "echo 'Configure your agent command in Settings. Worktree: {{worktree}}' && cat '{{promptFile}}'",
        plannerPromptTemplate: """
        You are a planning agent. Analyze the task and create a detailed implementation plan.
        
        Output a plan to PLAN.md with:
        1. Scope summary
        2. File-level changes (list each file to create/modify/delete)
        3. Risks and unknowns
        4. Test plan
        5. Ordered checklist of steps
        
        Do NOT implement anything. Only create the plan.
        """,
        executorPromptTemplate: """
        You are an executor agent. Follow the implementation plan in PLAN.md exactly.
        
        Constraints:
        - Keep changes minimal
        - Do not change tech stack unless required
        - Update/add tests where appropriate
        - Follow the checklist order
        
        Execute the plan step by step.
        """,
        nonInteractiveFlag: "--yes",
        blockedTimeoutMinutes: 3,
        maxConcurrentSessions: 1,
        defaultWorktreesRoot: "~/Worktrees/ClaudeControlCenter",
        editorCommand: "cursor",
        terminalCommand: "open -a Terminal"
    )
    
    /// Get the logs directory
    static var logsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("ClaudeCodeControlCenter/logs")
    }
    
    /// Get the data directory
    static var dataDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("ClaudeCodeControlCenter/data")
    }
}
