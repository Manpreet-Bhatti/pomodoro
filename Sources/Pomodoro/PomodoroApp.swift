import AppKit
import SwiftData
import SwiftUI
import UserNotifications

@main struct PomodoroApp: App {
    let container: ModelContainer
    @State private var engine: TimerEngine

    init() {
        container = try! ModelContainer(for: TaskItem.self, Session.self)
        let engine = TimerEngine(context: container.mainContext)
        engine.onFinish = Self.notify
        _engine = State(initialValue: engine)
        NSApplication.shared.setActivationPolicy(.regular)  // SwiftPM executables start as background apps
        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) {
                _, _ in
            }
        }
    }

    var body: some Scene {
        Window("Pomodoro", id: "main") {
            ContentView().tint(.sakura)
        }
        .environment(engine)
        .modelContainer(container)
        .commands {
            CommandMenu("Timer") {
                Button(engine.status == .running ? "Pause" : "Start") { engine.toggle() }
                    .keyboardShortcut("p")
                Button("Next Phase") { engine.forward() }.keyboardShortcut("]")
                Button("Restart / Previous Phase") { engine.back() }.keyboardShortcut("[")
            }
        }

        MenuBarExtra {
            MenuBarContent().environment(engine)
        } label: {
            Image(nsImage: .sakuraTimer)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView().environment(engine).tint(.sakura)
        }
    }

    private static func notify(_ finished: Phase) {
        NSSound(named: "Glass")?.play()
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(finished.label) done"
        content.body = finished.isBreak ? "Back to focus." : "Take a break."
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}

struct MenuBarContent: View {
    @Environment(TimerEngine.self) private var engine
    @AppStorage(Key.short) private var shortBreak = 5
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        let breakLength = Binding<Double>(
            get: { Double(engine.phase.isBreak ? engine.breakMinutes : shortBreak) },
            set: {
                let m = Int($0.rounded())
                if engine.phase.isBreak { engine.setBreakMinutes(m) } else { shortBreak = m }
            }
        )
        GlassEffectContainer(spacing: 12) {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Text(clock(engine.remaining))
                        .font(.system(size: 40, design: .rounded)).monospacedDigit()
                        .contentTransition(.numericText())
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .card()

                    let running = engine.status == .running
                    Button(
                        running ? "Stop" : "Start", systemImage: running ? "stop.fill" : "play.fill"
                    ) {
                        engine.toggle()
                    }
                    .labelStyle(.iconOnly).font(.title)
                    .buttonStyle(.glassProminent).buttonBorderShape(.circle)
                    .controlSize(.extraLarge).tint(.sakura)
                }
                .frame(height: 90)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Break Mode")
                        Spacer()
                        Text("\(Int(breakLength.wrappedValue)) \(Text("MINS").font(.caption))")
                    }
                    .font(.headline)
                    HStack {
                        Image(systemName: "figure.mind.and.body").foregroundStyle(.secondary)
                        Slider(value: breakLength, in: 1...60) { Text("Break length") }
                            .labelsHidden().tint(.sakura)
                    }
                }
                .padding(14)
                .card()

                HStack {
                    Button("Quit Pomodoro") { NSApp.terminate(nil) }
                    Spacer()
                    Button("Settings", systemImage: "gearshape.fill") {
                        NSApp.activate()
                        openSettings()
                    }
                    .labelStyle(.iconOnly).buttonBorderShape(.circle)
                }
                .buttonStyle(.glass)
            }
        }
        .padding(12)
        .frame(width: 300)
    }
}

extension View {
    func card() -> some View {
        glassEffect(in: .rect(cornerRadius: 16))
    }
}

func clock(_ t: TimeInterval) -> String {
    let s = Int(t.rounded(.up))
    return String(format: "%d:%02d", s / 60, s % 60)
}
