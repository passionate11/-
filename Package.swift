// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EyeRest",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "EyeRest", targets: ["EyeRest"])
    ],
    targets: [
        .executableTarget(
            name: "EyeRest",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("UserNotifications")
            ]
        )
    ]
)
