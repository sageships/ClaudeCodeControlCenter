import Foundation

enum SessionPhase: String, Codable {
    case planner
    case executor
    case direct
}

enum SessionStatus: String, Codable {
    case planning
    case awaitingApproval = "awaiting_approval"
    case running
    case queued
    case blocked
    case succeeded
    case failed
    case stopped
    
    var displayName: String {
        switch self {
        case .planning: return "Planning"
        case .awaitingApproval: return "Awaiting Approval"
        case .running: return "Running"
        case .queued: return "Queued"
        case .blocked: return "Blocked"
        case .succeeded: return "Succeeded"
        case .failed: return "Failed"
        case .stopped: return "Stopped"
        }
    }
    
    var color: String {
        switch self {
        case .planning, .running: return "blue"
        case .awaitingApproval: return "orange"
        case .queued: return "gray"
        case .blocked: return "yellow"
        case .succeeded: return "green"
        case .failed: return "red"
        case .stopped: return "gray"
        }
    }
    
    var isTerminal: Bool {
        switch self {
        case .succeeded, .failed, .stopped: return true
        default: return false
        }
    }
    
    var isActive: Bool {
        switch self {
        case .planning, .running: return true
        default: return false
        }
    }
}

struct Session: Identifiable, Codable, Hashable {
    var id: UUID
    var taskId: UUID
    var phase: SessionPhase
    var status: SessionStatus
    var startedAt: Date?
    var endedAt: Date?
    var exitCode: Int32?
    var pid: Int32?
    var logPath: String
    var planPath: String?
    var lastActivityAt: Date?
    var lastToolAction: String?
    
    init(
        id: UUID = UUID(),
        taskId: UUID,
        phase: SessionPhase,
        status: SessionStatus = .queued,
        startedAt: Date? = nil,
        endedAt: Date? = nil,
        exitCode: Int32? = nil,
        pid: Int32? = nil,
        logPath: String = "",
        planPath: String? = nil,
        lastActivityAt: Date? = nil,
        lastToolAction: String? = nil
    ) {
        self.id = id
        self.taskId = taskId
        self.phase = phase
        self.status = status
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.exitCode = exitCode
        self.pid = pid
        self.logPath = logPath
        self.planPath = planPath
        self.lastActivityAt = lastActivityAt
        self.lastToolAction = lastToolAction
    }
}
