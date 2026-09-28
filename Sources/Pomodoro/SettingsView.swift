import SwiftUI

struct SettingsView: View {
    @Environment(TimerEngine.self) private var engine
    @AppStorage(Key.focus) private var focus = 25
    @AppStorage(Key.short) private var short = 5
    @AppStorage(Key.long) private var long = 15
    @AppStorage(Key.longEvery) private var longEvery = 4
    @AppStorage(Key.autoStart) private var autoStart = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox("Time") {
                Grid(alignment: .leading, verticalSpacing: 8) {
                    GridRow {
                        Text("Focus:")
                        minutePicker($focus, 1...120)
                    }
                    GridRow {
                        Text("Short break:")
                        minutePicker($short, 1...60)
                    }
                    GridRow {
                        Text("Long break:")
                        minutePicker($long, 1...60)
                        Picker("Long break every", selection: $longEvery) {
                            ForEach(2...10, id: \.self) { Text("after \($0)") }
                        }
                        .labelsHidden().fixedSize()
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            GroupBox("Flow") {
                Toggle("Auto-start next phase", isOn: $autoStart)
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .frame(width: 360)
        .onChange(of: [focus, short, long]) { engine.reloadIfIdle() }
    }

    private func minutePicker(_ value: Binding<Int>, _ range: ClosedRange<Int>) -> some View {
        Picker("Minutes", selection: value) {
            ForEach(range, id: \.self) { Text("\($0) min") }
        }
        .labelsHidden().fixedSize()
    }
}
