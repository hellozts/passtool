// swift-tools-version: 5.9
// 仅用于在当前环境验证代码可编译（xcodebuild 因系统模拟器插件损坏无法运行）。
// 正式构建请使用 Xcode 打开 Passtool.xcodeproj。
import PackageDescription

let package = Package(
    name: "PasstoolVerify",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "PasstoolVerify",
            path: ".",
            exclude: ["iOS", "Passtool.xcodeproj", "project.yml", "Package.swift",
                      "macOS/Info.plist", "macOS/Passtool.entitlements"],
            sources: ["Shared", "macOS"]
        )
    ]
)
