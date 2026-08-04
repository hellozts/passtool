import SwiftUI

/// 解锁界面：输入主密码
struct UnlockView: View {
    @ObservedObject var vault = VaultManager.shared
    @State private var password = ""
    @State private var showPassword = false
    @State private var shake = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("Passtool 已锁定")
                .font(.title.bold())

            SecureInputField("输入主密码", text: $password, showText: $showPassword)
                .frame(maxWidth: 380)
                .focused($focused)
                .onSubmit(unlock)

            if let error = vault.lastError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.callout)
                    .offset(x: shake ? -8 : 0)
                    .animation(.easeInOut(duration: 0.05).repeatCount(3, autoreverses: true), value: shake)
            }

            Button(action: unlock) {
                Text("解锁")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: 380)
            .disabled(password.isEmpty)

            Spacer()
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(iOS)
        .background(Color(.systemBackground))
        #endif
        .onAppear { focused = true }
    }

    private func unlock() {
        if !vault.unlock(masterPassword: password) {
            shake.toggle()
            password = ""
        }
    }
}
