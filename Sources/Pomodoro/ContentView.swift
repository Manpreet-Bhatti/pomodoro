import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(TimerEngine.self) private var engine
    @Query(filter: #Predicate<TaskItem> { $0.parent == nil }, sort: \TaskItem.order) private
        var allRoots: [TaskItem]
    @State private var naming = false
    @State private var newGroup = ""

    var body: some View {
        @Bindable var engine = engine
        let groups = Set(allRoots.map(\.group) + [engine.group]).sorted()
        let roots = allRoots.filter { $0.group == engine.group }
        NavigationSplitView {
            List(roots, children: \.childList) { TaskRow(task: $0) }
                .navigationTitle(engine.group)
                .toolbar {
                    ToolbarItem {
                        Menu("Group", systemImage: "folder") {
                            Picker("Group", selection: $engine.group) {
                                ForEach(groups, id: \.self) { Text($0) }
                            }
                            .pickerStyle(.inline)
                            Button("New Group…") { naming = true }
                        }
                        .disabled(engine.status != .idle)
                    }
                    ToolbarItem {
                        Button("Add Task", systemImage: "plus") {
                            context.insert(
                                TaskItem(title: "New Task", order: roots.count, group: engine.group))
                        }
                    }
                }
                .alert("New Group", isPresented: $naming) {
                    TextField("Name", text: $newGroup)
                    Button("Create") {
                        let name = newGroup.trimmingCharacters(in: .whitespaces)
                        if !name.isEmpty { engine.group = name }
                        newGroup = ""
                    }
                    Button("Cancel", role: .cancel) { newGroup = "" }
                }
                .overlay {
                    if roots.isEmpty {
                        ContentUnavailableView(
                            "No Tasks", systemImage: "checklist",
                            description: Text("Click + to add a task."))
                    }
                }
                .navigationSplitViewColumnWidth(min: 260, ideal: 300)
        } detail: {
            TimerPane()
                .frame(minWidth: 500, minHeight: 560)
        }
    }
}

struct TaskRow: View {
    @Bindable var task: TaskItem
    @Environment(\.modelContext) private var context
    @Environment(TimerEngine.self) private var engine

    var body: some View {
        let focus = task.sessions.filter { $0.kind == .focus }
        HStack {
            Button {
                task.isDone.toggle()
            } label: {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(task.isDone ? Color.bark : .secondary, Color.sakura)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Done")
            .accessibilityAddTraits(task.isDone ? [.isToggle, .isSelected] : .isToggle)

            if task.isDone {
                Text(task.title).strikethrough().foregroundStyle(.secondary)
            } else {
                TextField("Task", text: $task.title)
            }
            Spacer()
            if !focus.isEmpty {
                let done = focus.filter(\.completed).count
                Text("\(done) 🍅 · \(minutes(focus))m")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    .accessibilityLabel("\(done) pomodoros, \(minutes(focus)) minutes")
            }
        }
        .contextMenu {
            Button("Start Pomodoro") { engine.start(task: task) }
            Button("Add Subtask") {
                context.insert(
                    TaskItem(title: "New Subtask", parent: task, order: task.children.count))
            }
            Divider()
            Button("Delete", role: .destructive) { context.delete(task) }
        }
    }
}

struct TimerPane: View {
    @Environment(TimerEngine.self) private var engine
    @Query(sort: \TaskItem.title) private var tasks: [TaskItem]
    @Query(sort: \Session.startedAt, order: .reverse) private var allSessions: [Session]

    var body: some View {
        @Bindable var engine = engine
        let sessions = allSessions.filter { $0.group == engine.group }
        let today = sessions.filter { Calendar.current.isDateInToday($0.startedAt) }
        VStack(spacing: 16) {
            Text(engine.phase.label).font(.title2.bold()).foregroundStyle(
                engine.phase.isBreak ? Color.bark : Color.sakura)
            Text(clock(engine.remaining))
                .font(.system(size: 80, weight: .light, design: .rounded)).monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(engine.phase.isBreak ? Color.bark : Color.sakura)
            HStack(spacing: 6) {
                let completed = engine.focusCount
                let progress = engine.duration > 0 ? engine.elapsed / engine.duration : 0
                ForEach(0..<engine.longEvery, id: \.self) { i in
                    let fill =
                        i < completed
                        ? 1 : (i == completed && engine.phase == .focus ? progress : 0)
                    Circle().fill(Color.secondary.opacity(0.25))
                        .overlay(alignment: .leading) {
                            Rectangle().fill(Color.sakura).frame(width: 8 * fill)
                        }
                        .clipShape(Circle())
                        .frame(width: 8, height: 8)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(
                "\(engine.focusCount) of \(engine.longEvery) sessions before long break")

            GlassEffectContainer(spacing: 16) {
                HStack(spacing: 16) {
                    Button("Back", systemImage: "backward.end.fill") { engine.back() }
                        .buttonStyle(.glass)
                    Button(
                        engine.status == .running ? "Pause" : "Start",
                        systemImage: engine.status == .running ? "pause.fill" : "play.fill"
                    ) { engine.toggle() }
                    .buttonStyle(.glassProminent).controlSize(.extraLarge)
                    .keyboardShortcut(.defaultAction)
                    Button("Forward", systemImage: "forward.end.fill") { engine.forward() }
                        .buttonStyle(.glass)
                }
            }
            .labelStyle(.iconOnly).font(.title2).buttonBorderShape(.circle)
            .controlSize(.large).tint(.sakura)

            Form {
                TextField("Session title", text: $engine.title)
                Picker("Task", selection: $engine.task) {
                    Text("None").tag(TaskItem?.none)
                    ForEach(tasks.filter { !$0.isDone && $0.group == engine.group }) {
                        Text($0.title).tag(Optional($0))
                    }
                }
                if engine.phase.isBreak {
                    Stepper(
                        "Break length: \(engine.breakMinutes) min",
                        value: Binding(get: { engine.breakMinutes }, set: engine.setBreakMinutes),
                        in: 1...60)
                }
            }
            .formStyle(.grouped).frame(maxWidth: 420).fixedSize(horizontal: false, vertical: true)

            GroupBox {
                HStack(spacing: 32) {
                    stat("Focus today", "\(minutes(today.filter { $0.kind == .focus }))m")
                    stat("Breaks today", "\(minutes(today.filter { $0.kind.isBreak }))m")
                    stat(
                        "Sessions today",
                        "\(today.filter { $0.kind == .focus && $0.completed }.count)")
                    stat(
                        "All time", "\(sessions.filter { $0.kind == .focus && $0.completed }.count)")
                }
                .padding(.horizontal, 24).padding(.vertical, 12)
            }
            .fixedSize()

            List(sessions.prefix(50)) { s in
                HStack {
                    Image(systemName: s.kind == .focus ? "brain.head.profile" : "cup.and.saucer")
                    Text(s.title)
                    if let t = s.task, t.title != s.title {
                        Text(t.title).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(s.elapsedSeconds / 60)m\(s.completed ? "" : " (skipped)")")
                        .monospacedDigit()
                    Text(s.startedAt, format: .dateTime.month().day().hour().minute())
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .padding()
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack {
            Text(value).font(.title2.bold()).monospacedDigit().foregroundStyle(Color.bark)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

func minutes(_ sessions: [Session]) -> Int {
    sessions.reduce(0) { $0 + $1.elapsedSeconds } / 60
}
