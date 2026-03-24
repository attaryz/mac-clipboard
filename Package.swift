// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClipboardManager",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "ClipboardManager",
            targets: ["ClipboardManager"]
        )
    ],
    targets: [
        .executableTarget(
            name: "ClipboardManager",
            path: "Sources",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
