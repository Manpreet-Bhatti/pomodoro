import Foundation
import Testing

@testable import Pomodoro

@MainActor @Test func focusSplitsAcrossHours() {
    let h = Harness()
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = .gmt
    let day = Date(timeIntervalSince1970: 0)
    let at = { (minute: Int) in day + TimeInterval(minute * 60) }
    let sessions = [
        // 10:40–11:20, no pauses.
        Session(
            title: "Focus", kind: .focus, startedAt: at(640), endedAt: at(680),
            plannedSeconds: 2400, elapsedSeconds: 2400, completed: true, task: nil),
        Session(
            title: "Break", kind: .shortBreak, startedAt: at(680), endedAt: at(690),
            plannedSeconds: 600, elapsedSeconds: 600, completed: true, task: nil),
        // 12:00–13:00 on the wall, 25 minutes of it focused.
        Session(
            title: "Focus", kind: .focus, startedAt: at(720), endedAt: at(780),
            plannedSeconds: 1500, elapsedSeconds: 1500, completed: true, task: nil),
    ]
    sessions.forEach(h.container.mainContext.insert)

    let hours = focusByHour(sessions, day: day, calendar: cal)
    #expect(hours[10] == 1200)
    #expect(hours[11] == 1200)
    #expect(hours[12] == 1500)
    #expect(hours.reduce(0, +) == 3900)
}
