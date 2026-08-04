import SwiftUI
import UIKit

@main
struct PasstoolApp: App {
    @ObservedObject private var vault = VaultManager.shared
    @StateObject private var idle = IdleMonitor.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(vault)
                #if os(iOS)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in idle.bump() }
                )
                #endif
                .onAppear { startMonitoring() }
                .onChange(of: scenePhase) { phase in
                    if phase == .background {
                        vault.lock()
                    } else if phase == .active {
                        idle.bump()
                    }
                }
        }
    }

    private func startMonitoring() {
        idle.onIdle = { vault.lock() }
        idle.start()
    }
}
