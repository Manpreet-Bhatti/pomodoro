# Pomodoro

A native macOS Pomodoro timer built with SwiftUI and SwiftData. It alternates between focus sessions and short or long breaks, keeps a nested task list organized into groups, and logs every session so you can see how much time each task took.

## Features

- **Focus / short break / long break cycle.** A long break comes after every N focus sessions (4 by default).
- **Tasks and subtasks**, grouped into named groups (for example "Work" or "Personal"). Start a pomodoro straight from a task. Each task shows how many pomodoros and focus minutes it has used.
- **Session history.** Each phase is saved, including partial ones when you skip ahead, which are marked "skipped".
- **Session log.** Sessions are grouped by month. Each day shows 24 hour bars that get brighter the more you focused in that hour. Expand a day to see its focus and break blocks on a timeline, like a calendar day view. History is stored locally in `~/Library/Application Support/Pomodoro/` and takes up about 1 MB per year of daily use.
- **Menu bar extra** that shows the current phase and time left, with Start/Pause and Skip.
- **Notifications and sound** when a phase ends. Notifications only work when the app runs as a bundled `.app` (see [Build](#build)).
- **Adjustable break length** for the current break, on top of the defaults in Settings.

### Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| ⌘P | Start / Pause |
| ⌘] | Next phase |
| ⌘[ | Restart phase (press again within 5s to go to the previous phase) |
| ⌘N | New task |
| ⌘, | Settings |

### Settings

Focus length (1–120 min), short break (1–60), long break (1–60), how many focus sessions before a long break (2–10), auto-start the next phase, and show in menu bar.

## Requirements

- macOS 26 or later
- Swift 6.2 toolchain (Xcode 26 or later)

The project has no third-party dependencies.

## Run

```sh
swift run
```

This starts the SwiftPM executable directly. The timer, tasks, and menu bar all work, but **system notifications are turned off** because a bare executable has no bundle identifier. The end-of-phase sound still plays.

## Build

Debug build:

```sh
swift build
```

Release `.app` bundle, with icon, `Info.plist`, and an ad-hoc signature, so notifications work:

```sh
./bundle.sh
open build/Pomodoro.app
```

`bundle.sh` runs `swift build -c release`, wraps the binary in `build/Pomodoro.app`, renders `Assets/AppIcon.svg` into an `.icns` with `Assets/make-icns.swift`, and signs the result with `codesign -s -`. To install, copy `build/Pomodoro.app` into `/Applications`.

## Test

```sh
swift test
```

The tests use Swift Testing and live in `Tests/PomodoroTests/TimerEngineTests.swift`. They drive `TimerEngine` with an injected clock, an in-memory SwiftData store, and a throwaway `UserDefaults` suite, so they finish instantly and never touch your real data or settings. They cover the phase sequence, pausing, skipping and logging partial sessions, restart/back, overriding a break's length, and scoping tasks to groups.
