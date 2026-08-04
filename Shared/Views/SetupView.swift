import SwiftUI

/// 首次使用：创建主密码
struct SetupView: View {
    @ObservedObject var vault = VaultManager.shared
    @ObservedObject private var settings = AppSettings.shared

    @State private var password = ""
    @State private var confirm = ""
    @State private var showPassword = false
    @State private var error: String?
    @State private var showFolderPicker = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            VStack(spacing: 6) {
                Text("创建密码库")
                    .font(.title.bold())
                Text("设置一个主密码，用于加密你的所有数据。请尽量牢记。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: 14) {
                SecureInputField("主密码", text: $password, showText: $showPassword)
                SecureInputField("确认主密码", text: $confirm, showText: .constant(false))

                if !password.isEmpty {
                    StrengthBar(score: PasswordGenerator.strength(password))
                }

                if let error = error {
                    Text(error).foregroundStyle(.red).font(.callout)
                }
            }
            .frame(maxWidth: 380)

            VStack(spacing: 10) {
                Button(action: createVault) {
                    Text("创建密码库")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(password.isEmpty || confirm.isEmpty)

                Button(action: chooseLocation) {
                    Label("保存目录：\(shortLocation)", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
            .frame(maxWidth: 380)

            Spacer()
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(iOS)
        .background(Color(.systemBackground))
        #endif
        #if os(iOS)
        .sheet(isPresented: $showFolderPicker) {
            iOSFolderPicker { url in
                showFolderPicker = false
                if let url = url {
                    VaultStore.setVaultLocation(url)
                    settings.objectWillChange.send()
                }
            }
        }
        #endif
    }

    private var shortLocation: String {
        let path = DirectoryPicker.currentLocationDescription()
        if path.count > 40 {
            return "…" + path.suffix(38)
        }
        return path
    }

    private func chooseLocation() {
        #if os(macOS)
        DirectoryPicker.pick { url in
            if let url = url {
                VaultStore.setVaultLocation(url)
                settings.objectWillChange.send()
            }
        }
        #else
        showFolderPicker = true
        #endif
    }

    private func createVault() {
        error = nil
        guard password.count >= 4 else { error = "主密码至少 4 位"; return }
        guard password == confirm else { error = "两次输入的主密码不一致"; return }
        do {
            try vault.createVault(masterPassword: password)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// 带显示/隐藏切换的密码输入框
struct SecureInputField: View {
    let title: String
    @Binding var text: String
    @Binding var showText: Bool

    init(_ title: String, text: Binding<String>, showText: Binding<Bool>) {
        self.title = title
        self._text = text
        self._showText = showText
    }

    var body: some View {
        HStack {
            if showText {
                TextField(title, text: $text)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
            } else {
                SecureField(title, text: $text)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
            }
            Button {
                showText.toggle()
            } label: {
                Image(systemName: showText ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            #if os(macOS)
            .help(showText ? "隐藏" : "显示")
            #endif
        }
    }
}

/// 密码强度条
struct StrengthBar: View {
    let score: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < score ? color : Color.secondary.opacity(0.2))
                        .frame(height: 6)
                }
            }
            Text("强度：\(PasswordGenerator.strengthLabel(score))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var color: Color {
        switch score {
        case 0, 1: return .red
        case 2: return .orange
        case 3: return .yellow
        default: return .green
        }
    }
}
