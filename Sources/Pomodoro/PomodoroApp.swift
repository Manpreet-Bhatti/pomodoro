import AppKit
import SwiftData
import SwiftUI
import UserNotifications

@main struct PomodoroApp: App {
    let container: ModelContainer
    @State private var engine: TimerEngine
    @AppStorage(Key.menuBar) private var showMenuBar = true

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

        MenuBarExtra(isInserted: $showMenuBar) {
            MenuBarContent().environment(engine)
        } label: {
            Image(nsImage: .sakuraTimer)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView().environment(engine).tint(.sakura)
        }
    }

    private static func notify(_ finished: Phase) {
        NSSound(named: "Glass")?.play()
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(finished.label) Done"
        content.body = finished.isBreak ? "Back to focus." : "Take a break."
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}

struct MenuBarContent: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Text("\(engine.phase.label) · \(clock(engine.remaining))")
        Button(engine.status == .running ? "Pause" : "Start") { engine.toggle() }
        Button("Skip") { engine.forward() }
        Divider()
        Button("Settings…") {
            NSApp.activate()
            openSettings()
        }
        .keyboardShortcut(",")
        Button("Quit Pomodoro") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}

func clock(_ t: TimeInterval) -> String {
    let s = Int(t.rounded(.up))
    return String(format: "%d:%02d", s / 60, s % 60)
}
