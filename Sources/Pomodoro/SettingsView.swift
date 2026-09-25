import SwiftUI

struct SettingsView: View {
    @Environment(TimerEngine.self) private var engine
    @AppStorage(Key.focus) private var focus = 25
    @AppStorage(Key.short) private var short = 5
    @AppStorage(Key.long) private var long = 15
    @AppStorage(Key.longEvery) private var longEvery = 4
    @AppStorage(Key.autoStart) private var autoStart = true

    var body: some View {
        Form {
            Stepper("Focus: \(focus) min", value: $focus, in: 1...120)
            Stepper("Short break: \(short) min", value: $short, in: 1...60)
            Stepper("Long break: \(long) min", value: $long, in: 1...60)
            Stepper("Long break every \(longEvery) pomodoros", value: $longEvery, in: 2...10)
            Toggle("Auto-start next phase", isOn: $autoStart)
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .onChange(of: [focus, short, long]) { engine.reloadIfIdle() }
    }
}
