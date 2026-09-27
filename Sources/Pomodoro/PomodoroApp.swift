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

    var body: some View {
        let breakLength = Binding(
            get: { engine.phase.isBreak ? engine.breakMinutes : shortBreak },
            set: { if engine.phase.isBreak { engine.setBreakMinutes($0) } else { shortBreak = $0 } }
        )
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Text(clock(engine.remaining))
                    .font(.system(size: 40, design: .monospaced)).monospacedDigit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .card()

                let running = engine.status == .running
                Button(running ? "Stop" : "Start", systemImage: running ? "stop.fill" : "play.fill")
                {
                    engine.toggle()
                }
                .labelStyle(.iconOnly).buttonStyle(.plain)
                .font(.system(size: 24)).foregroundStyle(Color.sakura)
                .frame(width: 56, height: 56)
                .background(.background, in: Circle())
                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                .frame(width: 76).frame(maxHeight: .infinity)
                .card()
            }
            .frame(height: 110)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Break Mode")
                    Spacer()
                    Text("\(breakLength.wrappedValue) \(Text("MINS").font(.caption))")
                }
                .font(.headline)
                IconSlider(value: breakLength, range: 1...60, icon: "figure.mind.and.body")
            }
            .padding(14)
            .card()

            HStack {
                Button("Quit Pomodoro") { NSApp.terminate(nil) }
                Spacer()
                SettingsLink { Image(systemName: "gearshape.fill").font(.title2) }
            }
            .buttonStyle(.plain).font(.headline).foregroundStyle(.secondary)
            .padding(.horizontal, 4)
        }
        .padding(12)
        .frame(width: 300)
    }
}

/// Capsule slider whose thumb carries an icon.
private struct IconSlider: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let icon: String

    var body: some View {
        GeometryReader { geo in
            let knob: CGFloat = 30
            let span = geo.size.width - knob
            let steps = CGFloat(range.upperBound - range.lowerBound)
            let x = span * CGFloat(value - range.lowerBound) / steps
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule().fill(Color.sakura.opacity(0.35)).frame(width: knob + x)
                Image(systemName: icon).font(.caption).foregroundStyle(.secondary)
                    .frame(width: knob - 4, height: knob - 4)
                    .background(.background, in: Circle())
                    .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                    .padding(2)
                    .offset(x: x)
            }
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { g in
                    let f = min(max((g.location.x - knob / 2) / span, 0), 1)
                    value = range.lowerBound + Int((f * steps).rounded())
                })
        }
        .frame(height: 30)
        .accessibilityRepresentation { Stepper("Break length", value: $value, in: range) }
    }
}

extension View {
    fileprivate func card() -> some View {
        background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
    }
}

func clock(_ t: TimeInterval) -> String {
    let s = Int(t.rounded(.up))
    return String(format: "%d:%02d", s / 60, s % 60)
}
