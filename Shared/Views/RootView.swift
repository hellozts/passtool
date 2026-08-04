import SwiftUI

/// 应用根视图：根据密码库状态显示对应界面
struct RootView: View {
    @ObservedObject var vault = VaultManager.shared

    var body: some View {
        Group {
            switch vault.state {
            case .needsSetup:
                SetupView()
            case .locked:
                UnlockView()
            case .unlocked:
                MainView()
            }
        }
        .animation(.default, value: vault.state)
    }
}
