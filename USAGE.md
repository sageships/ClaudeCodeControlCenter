# Claude Code Control Center - User Guide

A macOS app that helps you manage multiple AI coding agent sessions across different tasks and git branches. Think of it as a **project manager for AI-assisted development**.

---

## 🎯 What Problem Does This Solve?

When using AI coding agents (like Claude Code), you often:
- Work on multiple features/bugs simultaneously
- Need isolated git branches for each task
- Want to review AI-generated plans before execution
- Need to track what the AI is doing across sessions

**Claude Code Control Center** solves all of this with a clean GUI.

---

## 📖 Core Concepts

### Workspace
A **Workspace** = A git repository you want to work in.

Example: Your `peakflo-frontend` repo is one workspace.

### Task  
A **Task** = A specific piece of work (feature, bug fix, refactor).

Each task gets:
- Its own **git branch** (e.g., `task/add-dark-mode`)
- Its own **git worktree** (isolated folder copy of your repo)
- Its own **AI sessions**

### Session
A **Session** = One run of an AI coding agent.

Sessions can be:
- **Planner** → AI creates a plan (PLAN.md), doesn't code yet
- **Executor** → AI follows the plan and writes code
- **Direct** → AI plans and executes in one go (skip the review step)

### Plan-First Workflow
The recommended workflow:
1. AI creates a plan → you review it
2. You approve/edit the plan
3. AI executes the approved plan

This gives you control over what the AI will build before it builds it.

---

## 🖥️ UI Walkthrough

The app has **3 columns**:

```
┌─────────────┬─────────────────┬──────────────────────────┐
│  SIDEBAR    │   TASK LIST     │      TASK DETAIL         │
│ (Workspaces)│   (Your tasks)  │  (Sessions, logs, plan)  │
└─────────────┴─────────────────┴──────────────────────────┘
```

---

## 📂 Sidebar (Left Column) - Workspaces

### What You See
- List of your added git repositories
- "+" button to add new workspace
- Gear icon → Settings

### Adding a Workspace

1. Click **"+"** button
2. Fill in:
   - **Name**: Display name (e.g., "Peakflo Frontend")
   - **Repo Path**: Full path to your git repo (e.g., `/Users/you/Developer/peakflo-frontend`)
   - **Base Branch**: Default branch to create tasks from (usually `main` or `develop`)
   - **Worktrees Root**: Where task folders will be created (default: `~/Worktrees/ClaudeControlCenter`)

3. Click **Create**

### What Happens Behind the Scenes
- The app stores your workspace config
- When you create tasks, it will use `git worktree` to create isolated copies

---

## 📋 Task List (Middle Column)

### What You See
- List of tasks for the selected workspace
- Status badge for each task (based on latest session)
- "+" button to create new task

### Creating a Task

1. Select a workspace in sidebar
2. Click **"+"** button
3. Fill in:
   - **Title**: What you're building (e.g., "Add dark mode toggle")
   - **Branch Name**: Auto-suggested, or customize (e.g., `task/dark-mode`)
   - **Base Branch**: Branch to create from (defaults to workspace setting)
   - **Mode**: 
     - **Plan First** (recommended) → AI plans, you approve, then AI executes
     - **Direct** → AI does everything in one session

4. Click **Create Task**

### What Happens Behind the Scenes
```bash
# The app runs these git commands for you:
git worktree add ~/Worktrees/ClaudeControlCenter/task-dark-mode -b task/dark-mode
```

Now you have an isolated copy of your repo at that path, on its own branch.

---

## 🔍 Task Detail (Right Column)

This is where the magic happens. Select a task to see:

### Header Section
- **Task title** and branch name
- **Quick actions**:
  - 📁 Open in Finder → Opens the worktree folder
  - 💻 Open in Terminal → Opens Terminal at worktree path
  - ✏️ Open in Editor → Opens in your configured editor (default: Cursor)

### Sessions Section
Shows all AI sessions for this task:

| Status | Meaning |
|--------|---------|
| 🔵 Planning | Planner AI is running, creating PLAN.md |
| 🟠 Awaiting Approval | Plan ready — waiting for you to approve |
| 🔵 Running | Executor AI is running, writing code |
| ⏳ Queued | Waiting for another session to finish |
| 🟡 Blocked | AI hasn't output anything for 3+ minutes (might be stuck) |
| 🟢 Succeeded | Completed successfully |
| 🔴 Failed | Exited with error |
| ⚫ Stopped | You manually stopped it |

### Action Buttons

**Start Session** → Starts a new AI session
- If mode is "Plan First": Starts a Planner session
- If mode is "Direct": Starts a Direct session that plans + executes

**Approve Plan** (only shows when status = Awaiting Approval)
- Opens the plan for review
- You can edit it
- Click "Approve & Execute" to start the Executor

**Stop** → Kills a running session

**View Log** → Shows real-time output from the AI

### Plan Viewer
When a planner session completes, you'll see the generated PLAN.md here.
- Review what the AI wants to do
- Edit if needed
- Approve to proceed

### Log Viewer
Real-time streaming log of what the AI is outputting.
- Shows the last 500 lines
- Updates as the AI works
- Useful for debugging

---

## ⚙️ Settings

Click the **gear icon** in the sidebar to configure:

### Agent Command Template
The command used to run your AI agent. Placeholders:
- `{{worktree}}` → Path to the task's worktree
- `{{promptFile}}` → Path to the prompt file
- `{{mode}}` → "planner" or "executor" or "direct"
- `{{nonInteractiveFlag}}` → Auto-added for executor (e.g., `--dangerously-skip-permissions`)

**Default:**
```
claude --worktree {{worktree}} --prompt-file {{promptFile}} {{nonInteractiveFlag}}
```

### Planner Prompt Template
Instructions given to the AI in planner mode. Default tells it to create PLAN.md with scope, files to change, risks, and checklist.

### Executor Prompt Template  
Instructions for executor mode. Default tells it to follow PLAN.md exactly.

### Blocked Timeout (minutes)
If an AI session produces no output for this long, it's marked as "Blocked". Default: 3 minutes.

### Max Concurrent Sessions
How many AI sessions can run at once. Default: 1 (queues the rest).

### Editor Command
Which app to open files in. Default: `cursor`

---

## 🔄 Typical Workflow

### 1. Setup (one time)
1. Open the app
2. Add your repository as a Workspace
3. (Optional) Tweak settings for your AI agent

### 2. Start a Task
1. Select your workspace
2. Create a new task with a descriptive title
3. Choose "Plan First" mode

### 3. Planning Phase
1. Click "Start Session" → Planner AI starts
2. Wait for status to change to "Awaiting Approval"
3. Review the generated PLAN.md

### 4. Approval
1. Read the plan carefully
2. Edit anything you disagree with
3. Click "Approve & Execute"

### 5. Execution Phase
1. Executor AI runs, following your approved plan
2. Watch the log for progress
3. Wait for "Succeeded" status

### 6. Review & Merge
1. Open in your editor to review changes
2. Run tests locally
3. Commit and push
4. Create PR from the task branch

### 7. Cleanup
- Delete the task (optionally removes worktree and branch)
- Or keep it for future work on that feature

---

## 💡 Tips

### Why Use Worktrees?
Git worktrees let you have multiple branches checked out simultaneously in different folders. Benefits:
- No stashing/switching needed
- Each task is completely isolated
- You can have AI working on one task while you manually work on another

### When to Use Direct Mode
Use "Direct" mode when:
- Task is simple and well-defined
- You trust the AI to make good decisions
- You want speed over review

Use "Plan First" when:
- Task is complex
- You want to review before AI writes code
- You're not sure how the AI will approach it

### Blocked Sessions
If a session is marked "Blocked", the AI might be:
- Waiting for user input (but can't in non-interactive mode)
- Stuck on a long operation
- Actually crashed but process is still running

Try: View the log, then Stop and restart if needed.

---

## 🗂️ Data Storage

The app stores data in:
```
~/Library/Application Support/ClaudeCodeControlCenter/
├── data/
│   ├── workspaces.json
│   ├── tasks.json
│   ├── sessions.json
│   └── settings.json
└── logs/
    └── <task-id>/
        └── <session-id>.log
```

Worktrees are created in your configured root (default: `~/Worktrees/ClaudeControlCenter/`).

---

## 🚨 Troubleshooting

### "Damaged app" error on first run
Run in Terminal:
```bash
xattr -cr /Applications/ClaudeCodeControlCenter.app
```

### Task creation fails
- Make sure the repo path exists and is a valid git repo
- Check you have write permission to the worktrees root folder
- Ensure the branch name doesn't already exist

### Session stuck on "Running" forever
- Check the log for errors
- The AI might be waiting for input
- Stop the session and review what happened

### Can't find my worktree
Check:
```bash
ls ~/Worktrees/ClaudeControlCenter/
```
Or use the "Open in Finder" button on the task.

---

## 🔗 Requirements

- **macOS 14.0+** (Sonoma or later)
- **Git** installed
- An AI coding agent CLI (e.g., Claude Code, Cursor CLI, Aider)

---

## 📝 Version

**v1.0.0** - Initial Release

---

*Built with ❤️ by Sage*
