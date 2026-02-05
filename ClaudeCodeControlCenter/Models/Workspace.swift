import Foundation

struct Workspace: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var repoPath: String
    var defaultBaseBranch: String
    var worktreesRoot: String
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        repoPath: String,
        defaultBaseBranch: String = "main",
        worktreesRoot: String = "~/Worktrees/ClaudeControlCenter",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.repoPath = repoPath
        self.defaultBaseBranch = defaultBaseBranch
        self.worktreesRoot = (worktreesRoot as NSString).expandingTildeInPath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
