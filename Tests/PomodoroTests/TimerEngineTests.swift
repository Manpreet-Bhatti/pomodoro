import Foundation
import SwiftData
import Testing

@testable import Pomodoro

@MainActor final class Harness {
    var now = Date(timeIntervalSince1970: 0)
    let container = try! ModelContainer(
        for: TaskItem.self, Session.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    lazy var engine = TimerEngine(
        context: container.mainContext,
        defaults: UserDefaults(suiteName: UUID().uuidString)!,
        clock: { [unowned self] in self.now })

    func run(_ seconds: TimeInterval) {
        now += seconds
        engine.tick()
    }
    var sessions: [Session] { try! container.mainContext.fetch(FetchDescriptor<Session>()) }
}

@MainActor @Test func phaseSequence() {
    let h = Harness()
    h.engine.start()
    var seen: [Phase] = []
    for _ in 0..<9 {
        seen.append(h.engine.phase)
        h.run(h.engine.remaining)
    }
    #expect(
        seen == [
            .focus, .shortBreak, .focus, .shortBreak, .focus, .shortBreak, .focus, .longBreak,
            .focus,
        ])
    #expect(h.sessions.count == 9)
    #expect(h.sessions.allSatisfy { $0.completed })
    #expect(minutes(h.sessions.filter { $0.kind == .focus }) == 5 * 25)
    #expect(minutes(h.sessions.filter { $0.kind.isBreak }) == 3 * 5 + 15)
}

@MainActor @Test func pauseFreezesTime() {
    let h = Harness()
    h.engine.start()
    h.run(60)
    h.engine.pause()
    h.run(600)
    #expect(h.engine.remaining == 24 * 60)
    h.engine.start()
    h.run(60)
    #expect(h.engine.remaining == 23 * 60)
}

@MainActor @Test func forwardLogsPartial() {
    let h = Harness()
    h.engine.title = "Write plan"
    h.engine.start()
    h.run(120)
    h.engine.forward()
    #expect(h.engine.phase == .shortBreak)
    #expect(h.engine.status == .running)
    let s = h.sessions.first!
    #expect(s.title == "Write plan" && s.elapsedSeconds == 120 && !s.completed)
}

@MainActor @Test func backRestartsThenGoesPrevious() {
    let h = Harness()
    h.engine.start()
    h.engine.forward()  // -> short break
    h.run(30)
    h.engine.back()  // >5s in: restart break
    #expect(h.engine.phase == .shortBreak && h.engine.remaining == 5 * 60)
    h.engine.back()  // fresh: previous phase
    #expect(h.engine.phase == .focus && h.engine.focusCount == 0)
}

@MainActor @Test func breakOverride() {
    let h = Harness()
    h.engine.start()
    h.run(25 * 60)
    h.engine.setBreakMinutes(10)
    #expect(h.engine.remaining == 10 * 60)
    h.run(10 * 60)
    #expect(h.engine.phase == .focus)
    #expect(h.sessions.contains { $0.kind == .shortBreak && $0.elapsedSeconds == 600 })
}
