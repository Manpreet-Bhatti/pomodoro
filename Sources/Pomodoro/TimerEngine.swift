import Foundation
import Observation
import SwiftData

enum Key {
    static let focus = "focusMin", short = "shortMin", long = "longMin"
    static let longEvery = "longEvery", autoStart = "autoStart"
}

@Observable @MainActor final class TimerEngine {
    enum Status { case idle, running, paused }

    var phase: Phase = .focus
    var status: Status = .idle
    var title = ""
    var task: TaskItem?
    private(set) var remaining: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    /// Focus phases done since the last long break.
    private(set) var focusCount = 0
    var onFinish: ((Phase) -> Void)?

    private var endDate: Date?
    private var startedAt: Date?
    private var breakOverride: Int?
    private var history: [(Phase, Int)] = []
    private var ticker: Timer?
    private let context: ModelContext
    private let defaults: UserDefaults
    private let clock: () -> Date

    init(
        context: ModelContext, defaults: UserDefaults = .standard,
        clock: @escaping () -> Date = { .now }
    ) {
        self.context = context
        self.defaults = defaults
        self.clock = clock
        defaults.register(defaults: [
            Key.focus: 25, Key.short: 5, Key.long: 15, Key.longEvery: 4, Key.autoStart: true,
        ])
        reset()
    }

    var elapsed: TimeInterval { duration - remaining }
    var longEvery: Int { defaults.integer(forKey: Key.longEvery) }
    var breakMinutes: Int { Int(duration / 60) }

    // MARK: controls

    func toggle() { status == .running ? pause() : start() }

    func start() {
        guard status != .running else { return }
        if startedAt == nil { startedAt = clock() }
        endDate = clock() + remaining
        status = .running
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    func pause() {
        guard status == .running else { return }
        tick()
        status = .paused
        ticker?.invalidate()
    }

    func start(task: TaskItem) {
        self.task = task
        title = task.title
        guard status == .idle else { return }
        if phase != .focus {
            phase = .focus
            reset()
        }
        start()
    }

    /// Skip to the next phase, logging whatever was done of this one.
    func forward() {
        tick()
        log(completed: false)
        advance(keepRunning: status == .running)
    }

    /// Restart the phase; if barely started, step back to the previous phase instead.
    func back() {
        tick()
        if elapsed <= 5, let (prev, count) = history.popLast() {
            log(completed: false)
            phase = prev
            focusCount = count
        }
        reset()
    }

    /// Change the current break's length (defaults come from Settings).
    func setBreakMinutes(_ minutes: Int) {
        guard phase.isBreak else { return }
        breakOverride = minutes
        let delta = TimeInterval(minutes * 60) - duration
        duration += delta
        endDate = endDate.map { $0 + delta }
        tick()
        if status != .running { remaining = max(0, remaining + delta) }
    }

    /// Pick up Settings changes if the phase hasn't started yet.
    func reloadIfIdle() {
        if status == .idle { reset() }
    }

    func tick() {
        guard status == .running, let endDate else { return }
        remaining = max(0, endDate.timeIntervalSince(clock()))
        if remaining == 0 { finish() }
    }

    // MARK: internals

    private func finish() {
        let done = phase
        log(completed: true)
        advance(keepRunning: defaults.bool(forKey: Key.autoStart))
        onFinish?(done)
    }

    private func advance(keepRunning: Bool) {
        history.append((phase, focusCount))
        if phase == .focus {
            focusCount += 1
            phase = focusCount >= longEvery ? .longBreak : .shortBreak
        } else {
            if phase == .longBreak { focusCount = 0 }
            breakOverride = nil
            phase = .focus
        }
        ticker?.invalidate()
        status = .idle
        reset()
        if keepRunning { start() }
    }

    private func reset() {
        let key =
            switch phase {
            case .focus: Key.focus
            case .shortBreak: Key.short
            case .longBreak: Key.long
            }
        duration =
            TimeInterval((phase.isBreak ? breakOverride : nil) ?? defaults.integer(forKey: key))
            * 60
        remaining = duration
        endDate = status == .running ? clock() + duration : nil
        startedAt = status == .running ? clock() : nil
        if status == .paused { status = .idle }
    }

    private func log(completed: Bool) {
        guard let startedAt, elapsed >= 1 else { return }
        context.insert(
            Session(
                title: phase == .focus
                    ? (title.isEmpty ? (task?.title ?? "Focus") : title) : phase.label,
                kind: phase, startedAt: startedAt, endedAt: clock(),
                plannedSeconds: Int(duration), elapsedSeconds: Int(elapsed.rounded()),
                completed: completed, task: phase == .focus ? task : nil))
        try? context.save()
    }
}
