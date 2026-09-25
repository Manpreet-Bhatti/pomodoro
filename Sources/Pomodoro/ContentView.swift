import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<TaskItem> { $0.parent == nil }, sort: \TaskItem.order) private var roots: [TaskItem]

    var body: some View {
        NavigationSplitView {
            List(roots, children: \.childList) { TaskRow(task: $0) }
                .navigationTitle("Tasks")
                .toolbar {
                    Button("Add Task", systemImage: "plus") {
                        context.insert(TaskItem(title: "New Task", order: roots.count))
                    }
                }
                .overlay {
                    if roots.isEmpty { ContentUnavailableView("No tasks", systemImage: "checklist", description: Text("Add one with +")) }
                }
                .navigationSplitViewColumnWidth(min: 260, ideal: 300)
        } detail: {
            TimerPane()
        }
        .frame(minWidth: 760, minHeight: 560)
    }
}

struct TaskRow: View {
    @Bindable var task: TaskItem
    @Environment(\.modelContext) private var context
    @Environment(TimerEngine.self) private var engine

    var body: some View {
        let focus = task.sessions.filter { $0.kind == .focus }
        HStack {
            Toggle("Done", isOn: $task.isDone).labelsHidden()
            TextField("Task", text: $task.title).strikethrough(task.isDone)
            Spacer()
            if !focus.isEmpty {
                Text("\(focus.filter(\.completed).count) 🍅 · \(minutes(focus))m")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .contextMenu {
            Button("Start Pomodoro") { engine.start(task: task) }
            Button("Add Subtask") {
                context.insert(TaskItem(title: "New Subtask", parent: task, order: task.children.count))
            }
            Divider()
            Button("Delete", role: .destructive) { context.delete(task) }
        }
    }
}

struct TimerPane: View {
    @Environment(TimerEngine.self) private var engine
    @Query(sort: \TaskItem.title) private var tasks: [TaskItem]
    @Query(sort: \Session.startedAt, order: .reverse) private var sessions: [Session]

    var body: some View {
        @Bindable var engine = engine
        let today = sessions.filter { Calendar.current.isDateInToday($0.startedAt) }
        VStack(spacing: 16) {
            Text(engine.phase.label).font(.title2).foregroundStyle(engine.phase.isBreak ? .green : .red)
            Text(clock(engine.remaining))
                .font(.system(size: 80, weight: .light, design: .rounded)).monospacedDigit()
            Text("Pomodoro \(engine.focusCount + (engine.phase == .focus ? 1 : 0)) of \(engine.longEvery)")
                .foregroundStyle(.secondary)

            HStack(spacing: 24) {
                Button("Back", systemImage: "backward.end.fill") { engine.back() }
                Button(engine.status == .running ? "Pause" : "Start",
                       systemImage: engine.status == .running ? "pause.fill" : "play.fill") { engine.toggle() }
                    .keyboardShortcut(.defaultAction)
                Button("Forward", systemImage: "forward.end.fill") { engine.forward() }
            }
            .labelStyle(.iconOnly).font(.title).buttonStyle(.borderless)

            Form {
                TextField("Session title", text: $engine.title)
                Picker("Task", selection: $engine.task) {
                    Text("None").tag(TaskItem?.none)
                    ForEach(tasks.filter { !$0.isDone }) { Text($0.title).tag(Optional($0)) }
                }
                if engine.phase.isBreak {
                    Stepper("Break length: \(engine.breakMinutes) min",
                            value: Binding(get: { engine.breakMinutes }, set: engine.setBreakMinutes), in: 1...60)
                }
            }
            .formStyle(.grouped).frame(maxWidth: 420).fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 32) {
                stat("Focus today", "\(minutes(today.filter { $0.kind == .focus }))m")
                stat("Breaks today", "\(minutes(today.filter { $0.kind.isBreak }))m")
                stat("Sessions today", "\(today.filter { $0.kind == .focus && $0.completed }.count)")
                stat("All time", "\(sessions.filter { $0.kind == .focus && $0.completed }.count)")
            }

            List(sessions.prefix(50)) { s in
                HStack {
                    Image(systemName: s.kind == .focus ? "brain.head.profile" : "cup.and.saucer")
                    Text(s.title)
                    if let t = s.task, t.title != s.title { Text(t.title).foregroundStyle(.secondary) }
                    Spacer()
                    Text("\(s.elapsedSeconds / 60)m\(s.completed ? "" : " (skipped)")").monospacedDigit()
                    Text(s.startedAt, format: .dateTime.month().day().hour().minute()).foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack {
            Text(value).font(.title2.bold()).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}

func minutes(_ sessions: [Session]) -> Int {
    sessions.reduce(0) { $0 + $1.elapsedSeconds } / 60
}
