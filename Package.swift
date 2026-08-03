// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AgentUsageDashboard",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AgentUsageDashboard", targets: ["AgentUsageDashboard"])
    ],
    targets: [
        .executableTarget(
            name: "AgentUsageDashboard",
            path: "Sources/AgentUsageDashboard"
        ),
        .testTarget(
            name: "AgentUsageDashboardTests",
            dependencies: ["AgentUsageDashboard"],
            path: "Tests/AgentUsageDashboardTests"
        )
    ]
)
