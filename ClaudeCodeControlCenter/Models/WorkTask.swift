import Foundation

enum TaskMode: String, Codable, CaseIterable {
    case planFirst = "plan_first"
    case direct = "direct"
    
    var displayName: String {
        switch self {
        case .planFirst: return "Plan First"
        case .direct: return "Direct"
        }
    }
}

struct WorkTask: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var description: String  // Detailed description of what to build
    var workspaceId: UUID
    var baseBranch: String
    var branchName: String
    var worktreePath: String
    var mode: TaskMode
    var agentCommandTemplate: String?
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        workspaceId: UUID,
        baseBranch: String,
        branchName: String,
        worktreePath: String,
        mode: TaskMode = .planFirst,
        agentCommandTemplate: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.workspaceId = workspaceId
        self.baseBranch = baseBranch
        self.branchName = branchName
        self.worktreePath = worktreePath
        self.mode = mode
        self.agentCommandTemplate = agentCommandTemplate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Generate a slug from task title for branch name suggestion
    static func suggestBranchName(from title: String) -> String {
        let slug = title
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)
            .prefix(50)
        return "task/\(slug)"
    }
}
