import Foundation
import SwiftData

enum Phase: String, Codable {
    case focus, shortBreak, longBreak

    var isBreak: Bool { self != .focus }
    var label: String {
        switch self {
        case .focus: "Focus"
        case .shortBreak: "Short Break"
        case .longBreak: "Long Break"
        }
    }
}

@Model final class TaskItem {
    var title: String
    var isDone = false
    var order: Int
    var createdAt = Date.now
    var parent: TaskItem?
    @Relationship(deleteRule: .cascade, inverse: \TaskItem.parent) var children: [TaskItem] = []
    @Relationship(deleteRule: .nullify, inverse: \Session.task) var sessions: [Session] = []

    init(title: String, parent: TaskItem? = nil, order: Int = 0) {
        self.title = title
        self.parent = parent
        self.order = order
    }

    /// nil for leaves so `List(children:)` shows no disclosure arrow.
    var childList: [TaskItem]? {
        children.isEmpty ? nil : children.sorted { $0.order < $1.order }
    }
}

@Model final class Session {
    var title: String
    var kindRaw: String
    var startedAt: Date
    var endedAt: Date
    var plannedSeconds: Int
    var elapsedSeconds: Int
    var completed: Bool
    var task: TaskItem?

    var kind: Phase { Phase(rawValue: kindRaw) ?? .focus }

    init(title: String, kind: Phase, startedAt: Date, endedAt: Date,
         plannedSeconds: Int, elapsedSeconds: Int, completed: Bool, task: TaskItem?) {
        self.title = title
        self.kindRaw = kind.rawValue
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.plannedSeconds = plannedSeconds
        self.elapsedSeconds = elapsedSeconds
        self.completed = completed
        self.task = task
    }
}
