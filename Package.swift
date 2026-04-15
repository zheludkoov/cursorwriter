// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TranslateHotkey",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "TranslateHotkey", targets: ["TranslateHotkey"])
    ],
    targets: [
        .target(
            name: "TranslateHotkeyCore",
            path: "Sources/TranslateHotkeyCore"
        ),
        .executableTarget(
            name: "TranslateHotkey",
            dependencies: ["TranslateHotkeyCore"],
            path: "Sources/TranslateHotkey"
        ),
        .testTarget(
            name: "TranslateHotkeyTests",
            dependencies: ["TranslateHotkeyCore"],
            path: "Tests/TranslateHotkeyTests"
        )
    ]
)
