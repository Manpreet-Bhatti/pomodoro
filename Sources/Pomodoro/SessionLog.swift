import SwiftUI

/// Focus seconds in each hour of `day`. Paused time is scaled out.
func focusByHour(_ sessions: [Session], day: Date, calendar: Calendar = .current) -> [TimeInterval] {
    let start = calendar.startOfDay(for: day)
    var hours = [TimeInterval](repeating: 0, count: 24)
    for s in sessions where s.kind == .focus {
        let wall = s.endedAt.timeIntervalSince(s.startedAt)
        guard wall > 0 else { continue }
        let rate = min(Double(s.elapsedSeconds) / wall, 1)
        for h in 0..<24 {
            let from = calendar.date(byAdding: .hour, value: h, to: start)!
            let overlap = min(from + 3600, s.endedAt).timeIntervalSince(max(from, s.startedAt))
            if overlap > 0 { hours[h] += overlap * rate }
        }
    }
    return hours
}

private func hm(_ minutes: Int) -> String {
    Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .narrow))
}

/// Month → day (hour strip) → day timeline.
struct SessionLog: View {
    let sessions: [Session]
    @State private var openMonths: Set<Date> = [
        Calendar.current.dateInterval(of: .month, for: .now)!.start
    ]

    var body: some View {
        let cal = Calendar.current
        let months = Dictionary(grouping: sessions) {
            cal.dateInterval(of: .month, for: $0.startedAt)!.start
        }
        List {
            ForEach(months.keys.sorted(by: >), id: \.self) { month in
                let inMonth = months[month]!
                let days = Dictionary(grouping: inMonth) { cal.startOfDay(for: $0.startedAt) }
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { openMonths.contains(month) },
                        set: { if $0 { openMonths.insert(month) } else { openMonths.remove(month) } })
                ) {
                    ForEach(days.keys.sorted(by: >), id: \.self) { day in
                        DayRow(day: day, sessions: days[day]!)
                    }
                } label: {
                    HStack {
                        Text(month, format: .dateTime.month(.wide).year()).font(.headline)
                        Spacer()
                        Text("\(hm(minutes(inMonth.filter { $0.kind == .focus }))) focus")
                            .foregroundStyle(.secondary).monospacedDigit()
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}

struct DayRow: View {
    let day: Date
    let sessions: [Session]

    var body: some View {
        let focus = sessions.filter { $0.kind == .focus }
        let done = focus.filter(\.completed).count
        DisclosureGroup {
            DayTimeline(day: day, sessions: sessions)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(day, format: .dateTime.weekday(.wide).month().day()).font(.subheadline.bold())
                HourStrip(hours: focusByHour(sessions, day: day)).accessibilityHidden(true)
                Text(
                    "^[\(done) session](inflect: true) · \(focus.count - done) skipped · \(hm(minutes(focus))) focus"
                )
                .textCase(.uppercase).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
        }
    }
}

/// 24 bars; brighter = more focus in that hour.
struct HourStrip: View {
    let hours: [TimeInterval]

    var body: some View {
        // Label columns span exactly 3 bar columns because both rows share the spacing.
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                ForEach(0..<8, id: \.self) { i in
                    Text(String(format: "%02d", i * 3)).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .font(.caption2.monospaced()).foregroundStyle(.secondary)
            HStack(spacing: 3) {
                ForEach(0..<24, id: \.self) { h in
                    Capsule()
                        .fill(Color.sakura.opacity(0.12 + 0.88 * min(hours[h] / 3600, 1)))
                        .frame(width: 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(height: 22)
        }
    }
}

/// Calendar-style day: hour lines with sessions placed at their clock times.
struct DayTimeline: View {
    let day: Date
    let sessions: [Session]
    private let hourHeight: CGFloat = 96

    var body: some View {
        let cal = Calendar.current
        let dayEnd = cal.date(byAdding: .day, value: 1, to: day)!
        let first = sessions.map { cal.component(.hour, from: $0.startedAt) }.min() ?? 0
        let last =
            sessions.map { cal.component(.hour, from: min($0.endedAt, dayEnd - 1)) }.max() ?? first
        let top = cal.date(byAdding: .hour, value: first, to: day)!
        let y = { (d: Date) in CGFloat(min(d, dayEnd).timeIntervalSince(top) / 3600) * hourHeight }

        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(first...last, id: \.self) { h in
                    Text(String(format: "%02d:00", h))
                        .font(.caption2.monospaced()).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .overlay(alignment: .top) { Divider().padding(.leading, 44) }
                        .frame(height: hourHeight)
                }
            }
            ForEach(sessions) { s in
                block(s, height: y(s.endedAt) - y(s.startedAt))
                    .padding(.leading, 48)
                    .offset(y: y(s.startedAt))
            }
        }
        .padding(.vertical, 8)
    }

    private func block(_ s: Session, height: CGFloat) -> some View {
        let tint = s.kind == .focus ? Color.sakura : Color.bark
        let range = (s.startedAt..<s.endedAt).formatted(.interval.hour().minute())
        // ponytail: no minimum height, so short breaks show as a thin bar; hover for details
        return HStack(alignment: .top, spacing: 6) {
            RoundedRectangle(cornerRadius: 1.5).fill(tint).frame(width: 3)
            if height >= 16 {
                VStack(alignment: .leading, spacing: 0) {
                    Text(s.title).font(.caption.bold())
                    if height >= 32 {
                        Text(s.completed ? range : "\(range) · skipped")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .lineLimit(1)
            }
        }
        .padding(.vertical, height >= 16 ? 2 : 0)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: max(height, 2), alignment: .top)
        .background(tint.opacity(0.18), in: .rect(cornerRadius: 4))
        .clipped()
        .help("\(s.title), \(range)")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(s.kind.label), \(range), \(s.title)\(s.completed ? "" : ", skipped")")
    }
}
