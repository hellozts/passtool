import SwiftUI
import AppKit

@main
struct PasstoolApp: App {
    @ObservedObject private var vault = VaultManager.shared
    @StateObject private var idle = IdleMonitor.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(vault)
                .frame(minWidth: 880, minHeight: 560)
                .onAppear { startMonitoring() }
                .onChange(of: scenePhase) { phase in
                    if phase == .background {
                        vault.lock()
                    }
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1040, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建条目") {
                    NotificationCenter.default.post(name: .passtoolNewEntry, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandMenu("密码库") {
                Button("立即锁定") { vault.lock() }
                    .keyboardShortcut("l", modifiers: .command)
            }
        }
    }

    private func startMonitoring() {
        idle.onIdle = { vault.lock() }
        idle.start()
    }
}

extension Notification.Name {
    static let passtoolNewEntry = Notification.Name("passtoolNewEntry")
}
