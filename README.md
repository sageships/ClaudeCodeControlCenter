# Claude Code Control Center

A macOS app for managing git worktrees and AI agent sessions with a Plan-first workflow.

![macOS 14+](https://img.shields.io/badge/macOS-14+-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-✓-green)

## Features

- **Workspace Management**: Register git repositories and configure worktree locations
- **Task + Worktree Lifecycle**: Create tasks that automatically set up git worktrees and branches
- **Plan-First Workflow**: 
  1. Planner agent creates implementation plan
  2. You review and approve (or edit) the plan
  3. Executor agent implements the plan
- **Direct Mode**: Skip planning and run agent directly
- **Live Logs**: Real-time log streaming with search
- **Concurrency Queue**: Control max concurrent sessions
- **Blocked Detection**: Auto-detect stalled sessions
- **Quick Actions**: Open worktrees in Finder, Terminal, or your editor

## Building

### Using Swift Package Manager

```bash
# Build
swift build

# Run
swift run ClaudeCodeControlCenter

# Build release
swift build -c release
```

### Using Xcode

1. Open the project folder in Xcode
2. Build and run (⌘R)

Or generate an Xcode project:

```bash
swift package generate-xcodeproj
open ClaudeCodeControlCenter.xcodeproj
```

## Quick Start

1. **Add a Workspace**: Click "+" in the sidebar to register a git repository
2. **Create a Task**: Select your workspace, click "New Task"
   - Enter a title describing what you want to accomplish
   - Choose base branch (e.g., `main`)
   - Branch name is auto-suggested from title
   - Select mode: "Plan First" or "Direct"
3. **Run the Agent**:
   - Plan First: Planner creates a plan → Review → Approve → Executor runs
   - Direct: Agent runs immediately
4. **Monitor**: View live logs, status, and last tool actions
5. **Cleanup**: Delete tasks to remove worktrees and branches

## Configuration

Access Settings via the menu bar or ⌘, to configure:

### General
- **Default Worktrees Root**: Where worktrees are created
- **Editor Command**: App to open worktrees (e.g., `Cursor`, `Visual Studio Code`)
- **Max Concurrent Sessions**: Limit parallel agent runs
- **Blocked Timeout**: Minutes before marking inactive session as blocked

### Agent
- **Command Template**: The shell command to run your agent
  - Placeholders: `{{worktree}}`, `{{mode}}`, `{{promptFile}}`, `{{nonInteractiveFlag}}`
- **Non-Interactive Flag**: Added during executor phase (e.g., `--dangerously-skip-permissions`)

### Prompts
- **Planner Prompt**: Instructions for planning phase
- **Executor Prompt**: Instructions for execution phase

## Testing with Echo Agent

To test without a real AI agent, use this command template:

```
echo 'Agent running in {{mode}} mode at {{worktree}}' && sleep 5 && echo 'Creating plan...' && echo '# Implementation Plan\n\n1. Step one\n2. Step two' > {{worktree}}/PLAN.md && echo 'Done!'
```

## Data Storage

Data is stored in:
- `~/Library/Application Support/ClaudeCodeControlCenter/data/` - JSON state files
- `~/Library/Application Support/ClaudeCodeControlCenter/logs/` - Session logs

## License

MIT
