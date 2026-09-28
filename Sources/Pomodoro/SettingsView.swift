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
            Section("Time") {
                minutePicker("Focus", $focus, 1...120)
                minutePicker("Short break", $short, 1...60)
                minutePicker("Long break", $long, 1...60)
                Picker("Long break every", selection: $longEvery) {
                    ForEach(2...10, id: \.self) { Text("\($0) sessions") }
                }
            }
            Section("Flow") {
                Toggle("Auto-start next phase", isOn: $autoStart)
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: 360)
        .onChange(of: [focus, short, long]) { engine.reloadIfIdle() }
    }

    private func minutePicker(_ label: String, _ value: Binding<Int>, _ range: ClosedRange<Int>)
        -> some View
    {
        Picker(label, selection: value) {
            ForEach(range, id: \.self) { Text("\($0) min") }
        }
    }
}
