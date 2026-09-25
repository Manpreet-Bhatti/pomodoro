// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Pomodoro",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(name: "Pomodoro"),
        .testTarget(name: "PomodoroTests", dependencies: ["Pomodoro"]),
    ]
)
