import Foundation

enum GitError: LocalizedError {
    case notARepository(String)
    case worktreeExists(String)
    case branchExists(String)
    case pathExists(String)
    case commandFailed(String)
    case worktreeNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .notARepository(let path):
            return "'\(path)' is not a git repository"
        case .worktreeExists(let path):
            return "Worktree already exists at '\(path)'"
        case .branchExists(let branch):
            return "Branch '\(branch)' already exists. Choose a different name or reuse the existing branch."
        case .pathExists(let path):
            return "Path '\(path)' already exists. Remove it first or choose a different worktree location."
        case .commandFailed(let message):
            return "Git command failed: \(message)"
        case .worktreeNotFound(let path):
            return "Worktree not found at '\(path)'"
        }
    }
}

/// Handles git operations for worktree management
@MainActor
class GitService: ObservableObject {
    private let shell: ShellRunner
    
    init(shell: ShellRunner) {
        self.shell = shell
    }
    
    /// Check if a path is a valid git repository
    func isValidRepository(_ path: String) async -> Bool {
        let expandedPath = (path as NSString).expandingTildeInPath
        do {
            let result = try await shell.run(
                ["git", "-C", expandedPath, "rev-parse", "--git-dir"]
            )
            return result.succeeded
        } catch {
            return false
        }
    }
    
    /// Fetch all remotes
    func fetchAll(repoPath: String) async throws {
        let expandedPath = (repoPath as NSString).expandingTildeInPath
        let result = try await shell.run(
            ["git", "-C", expandedPath, "fetch", "--all", "--prune"]
        )
        if !result.succeeded {
            throw GitError.commandFailed(result.stderr)
        }
    }
    
    /// Check if a branch exists locally or remotely
    func branchExists(repoPath: String, branch: String) async throws -> Bool {
        let expandedPath = (repoPath as NSString).expandingTildeInPath
        
        // Check local branches
        let localResult = try await shell.run(
            ["git", "-C", expandedPath, "branch", "--list", branch]
        )
        if !localResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        
        // Check remote branches
        let remoteResult = try await shell.run(
            ["git", "-C", expandedPath, "branch", "-r", "--list", "origin/\(branch)"]
        )
        return !remoteResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Create a new worktree with a new branch
    func createWorktree(
        repoPath: String,
        worktreePath: String,
        branchName: String,
        baseBranch: String
    ) async throws {
        let expandedRepoPath = (repoPath as NSString).expandingTildeInPath
        let expandedWorktreePath = (worktreePath as NSString).expandingTildeInPath
        
        // Check if path already exists
        if FileManager.default.fileExists(atPath: expandedWorktreePath) {
            throw GitError.pathExists(expandedWorktreePath)
        }
        
        // Check if branch already exists
        if try await branchExists(repoPath: expandedRepoPath, branch: branchName) {
            throw GitError.branchExists(branchName)
        }
        
        // Create parent directory if needed
        let parentDir = (expandedWorktreePath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(
            atPath: parentDir,
            withIntermediateDirectories: true
        )
        
        // Fetch latest
        try await fetchAll(repoPath: expandedRepoPath)
        
        // Create worktree with new branch based on origin/<baseBranch>
        let result = try await shell.run([
            "git", "-C", expandedRepoPath,
            "worktree", "add",
            expandedWorktreePath,
            "-b", branchName,
            "origin/\(baseBranch)"
        ])
        
        if !result.succeeded {
            throw GitError.commandFailed(result.stderr)
        }
    }
    
    /// Remove a worktree
    func removeWorktree(repoPath: String, worktreePath: String, deleteBranch: Bool = false) async throws {
        let expandedRepoPath = (repoPath as NSString).expandingTildeInPath
        let expandedWorktreePath = (worktreePath as NSString).expandingTildeInPath
        
        // Get the branch name before removing
        var branchName: String?
        if deleteBranch {
            let branchResult = try await shell.run([
                "git", "-C", expandedWorktreePath,
                "rev-parse", "--abbrev-ref", "HEAD"
            ])
            if branchResult.succeeded {
                branchName = branchResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Remove worktree
        let result = try await shell.run([
            "git", "-C", expandedRepoPath,
            "worktree", "remove", expandedWorktreePath, "--force"
        ])
        
        if !result.succeeded {
            // Try to just delete the directory if worktree remove fails
            try? FileManager.default.removeItem(atPath: expandedWorktreePath)
            
            // Prune worktrees
            _ = try? await shell.run([
                "git", "-C", expandedRepoPath,
                "worktree", "prune"
            ])
        }
        
        // Delete the branch if requested
        if deleteBranch, let branch = branchName, branch != "main" && branch != "master" {
            _ = try? await shell.run([
                "git", "-C", expandedRepoPath,
                "branch", "-D", branch
            ])
        }
    }
    
    /// List all worktrees for a repository
    func listWorktrees(repoPath: String) async throws -> [String] {
        let expandedPath = (repoPath as NSString).expandingTildeInPath
        let result = try await shell.run([
            "git", "-C", expandedPath,
            "worktree", "list", "--porcelain"
        ])
        
        if !result.succeeded {
            throw GitError.commandFailed(result.stderr)
        }
        
        // Parse worktree paths from output
        return result.stdout
            .components(separatedBy: "\n")
            .filter { $0.hasPrefix("worktree ") }
            .map { String($0.dropFirst("worktree ".count)) }
    }
    
    /// Get the current branch name
    func getCurrentBranch(worktreePath: String) async throws -> String {
        let expandedPath = (worktreePath as NSString).expandingTildeInPath
        let result = try await shell.run([
            "git", "-C", expandedPath,
            "rev-parse", "--abbrev-ref", "HEAD"
        ])
        
        if !result.succeeded {
            throw GitError.commandFailed(result.stderr)
        }
        
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
