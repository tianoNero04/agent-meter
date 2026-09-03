// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AgentUsageDashboard",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "AgentUsageDashboardKit", type: .dynamic, targets: ["AgentUsageDashboardKit"]),
        .executable(name: "AgentUsageDashboard", targets: ["AgentUsageDashboardLauncher"])
    ],
    targets: [
        .target(
            name: "AgentUsageDashboardKit",
            path: "Sources/AgentUsageDashboard",
            sources: [
                "App",
                "Core",
                "Data",
                "Features",
                "UI"
            ],
            resources: [
                .copy("Resources/AgentMeterLogoWhite.png"),
                .copy("Resources/ProviderIconCodex.png"),
                .copy("Resources/ProviderIconKimi.png")
            ]
        ),
        .executableTarget(
            name: "AgentUsageDashboardLauncher",
            dependencies: ["AgentUsageDashboardKit"],
            path: "Sources/AgentUsageDashboardLauncher"
        ),
        .testTarget(
            name: "AgentUsageDashboardTests",
            dependencies: ["AgentUsageDashboardKit"],
            path: "Tests/AgentUsageDashboardTests"
        )
    ]
)
