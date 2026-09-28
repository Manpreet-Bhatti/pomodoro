// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Pomodoro",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "Pomodoro"),
        .testTarget(name: "PomodoroTests", dependencies: ["Pomodoro"]),
    ]
)
