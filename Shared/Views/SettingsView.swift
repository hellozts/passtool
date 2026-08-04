import SwiftUI

struct SettingsView: View {
    @ObservedObject var vault = VaultManager.shared
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showChangePassword = false
    @State private var showCategoryManager = false
    @State private var showResetConfirm = false
    #if os(iOS)
    @State private var showFolderPicker = false
    #endif

    var body: some View {
        NavigationStack {
            Form {
                Section("保存目录") {
                    HStack {
                        Image(systemName: "folder")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading) {
                            Text(DirectoryPicker.hasCustomLocation ? "自定义目录" : "默认目录")
                                .font(.callout)
                            Text(DirectoryPicker.currentLocationDescription())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .truncationMode(.middle)
                        }
                        Spacer()
                    }
                    Button {
                        chooseLocation()
                    } label: {
                        Label("选择保存目录…", systemImage: "folder.badge.plus")
                    }
                    if DirectoryPicker.hasCustomLocation {
                        Button("恢复默认目录", role: .destructive) {
                            DirectoryPicker.resetToDefault()
                            settings.objectWillChange.send()
                        }
                    }
                }

                Section("自动锁定") {
                    Picker("无操作超时", selection: $settings.idleTimeoutSeconds) {
                        Text("15 秒").tag(15)
                        Text("30 秒").tag(30)
                        Text("1 分钟").tag(60)
                        Text("2 分钟").tag(120)
                        Text("5 分钟").tag(300)
                        Text("10 分钟").tag(600)
                    }
                }

                Section("安全") {
                    Button {
                        showChangePassword = true
                    } label: {
                        Label("修改主密码", systemImage: "key")
                    }
                    Button {
                        showResetConfirm = true
                    } label: {
                        Label("删除全部数据", systemImage: "trash")
                    }
                    .foregroundStyle(.red)
                }

                Section("分类") {
                    Button {
                        showCategoryManager = true
                    } label: {
                        Label("管理分类", systemImage: "tag")
                    }
                }

                Section("关于") {
                    LabeledContent("应用", value: "Passtool")
                    LabeledContent("加密", value: "AES-256-GCM + PBKDF2")
                    LabeledContent("版本", value: "1.0")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
            #if os(macOS)
            .frame(minWidth: 460, minHeight: 520)
            #endif
        }
        .sheet(isPresented: $showChangePassword) { ChangePasswordView() }
        .sheet(isPresented: $showCategoryManager) { CategoryManagerView() }
        .confirmationDialog("删除全部数据？此操作不可恢复！",
                            isPresented: $showResetConfirm,
                            titleVisibility: .visible) {
            Button("删除全部数据", role: .destructive) {
                vault.resetVault()
                dismiss()
            }
            Button("取消", role: .cancel) {}
        }
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
}

/// 修改主密码
struct ChangePasswordView: View {
    @ObservedObject var vault = VaultManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var current = ""
    @State private var new = ""
    @State private var confirm = ""
    @State private var showNew = false
    @State private var error: String?
    @State private var done = false

    var body: some View {
        VStack(spacing: 16) {
            SecureInputField("当前主密码", text: $current, showText: .constant(false))
            SecureInputField("新主密码", text: $new, showText: $showNew)
            SecureInputField("确认新主密码", text: $confirm, showText: .constant(false))

            if !new.isEmpty {
                StrengthBar(score: PasswordGenerator.strength(new))
            }
            if let error = error {
                Text(error).foregroundStyle(.red).font(.callout)
            }
            if done {
                Text("主密码已更新").foregroundStyle(.green).font(.callout)
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("更新") { update() }
                    .buttonStyle(.borderedProminent)
                    .disabled(current.isEmpty || new.isEmpty || confirm.isEmpty)
            }
        }
        .padding()
        .frame(maxWidth: 420)
        .navigationTitle("修改主密码")
    }

    private func update() {
        error = nil
        guard new.count >= 4 else { error = "新主密码至少 4 位"; return }
        guard new == confirm else { error = "两次新密码不一致"; return }
        do {
            try vault.changeMasterPassword(current: current, new: new)
            done = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { dismiss() }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// 分类管理
struct CategoryManagerView: View {
    @ObservedObject var vault = VaultManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var newName = ""
    @State private var newIcon = "tray"
    @State private var editingCategory: VaultCategory?

    private let icons = ["tray", "lock.shield", "creditcard", "note.text", "globe",
                         "envelope", "wifi", "server.rack", "person.crop.circle",
                         "key", "bookmark", "tag"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部栏
            HStack {
                Text("管理分类")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("完成") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        // 已有分类
                        VStack(alignment: .leading, spacing: 6) {
                            Text("已有分类")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                            if vault.data.categories.isEmpty {
                                Text("暂无分类，可在下方添加")
                                    .font(.callout)
                                    .foregroundStyle(.tertiary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                                    .background(Color.secondary.opacity(0.08),
                                                in: RoundedRectangle(cornerRadius: 10))
                            } else {
                                VStack(spacing: 2) {
                                    ForEach(vault.data.categories) { cat in
                                        row(for: cat)
                                    }
                                }
                                .background(Color.secondary.opacity(0.08),
                                            in: RoundedRectangle(cornerRadius: 10))
                            }
                        }

                        // 添加分类
                        VStack(alignment: .leading, spacing: 6) {
                            Text("添加分类")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)

                            VStack(spacing: 10) {
                                TextField("分类名称", text: $newName)
                                    .textFieldStyle(.roundedBorder)

                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                                    ForEach(icons, id: \.self) { ic in
                                        Image(systemName: ic)
                                            .frame(width: 36, height: 36)
                                            .background(newIcon == ic ? Color.accentColor.opacity(0.2) : Color.clear,
                                                        in: RoundedRectangle(cornerRadius: 8))
                                            .foregroundStyle(newIcon == ic ? Color.accentColor : Color.secondary)
                                            .onTapGesture { newIcon = ic }
                                    }
                                }

                                Button {
                                    let name = newName.trimmingCharacters(in: .whitespaces)
                                    guard !name.isEmpty else { return }
                                    vault.upsert(category: VaultCategory(name: name, icon: newIcon))
                                    newName = ""
                                    newIcon = "tray"
                                } label: {
                                    Label("添加分类", systemImage: "plus")
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                            .padding(12)
                            .background(Color.secondary.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 480)
        .sheet(item: $editingCategory) { cat in
            CategoryEditorView(category: cat)
        }
    }

    private func row(for cat: VaultCategory) -> some View {
        HStack {
            Image(systemName: cat.icon).foregroundStyle(.tint)
            Text(cat.name)
            Spacer()
            Button {
                editingCategory = cat
            } label: {
                Image(systemName: "pencil")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            Button(role: .destructive) {
                vault.deleteCategory(cat)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture { editingCategory = cat }
    }
}

/// 分类编辑表单（修改名称 / 图标）
struct CategoryEditorView: View {
    @ObservedObject var vault = VaultManager.shared
    @Environment(\.dismiss) private var dismiss
    let category: VaultCategory

    @State private var name: String = ""
    @State private var icon: String = "tray"

    private let icons = ["tray", "lock.shield", "creditcard", "note.text", "globe",
                         "envelope", "wifi", "server.rack", "person.crop.circle",
                         "key", "bookmark", "tag"]

    var body: some View {
        NavigationStack {
            Form {
                Section("名称") {
                    TextField("分类名称", text: $name)
                }
                Section("图标") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(icons, id: \.self) { ic in
                            Image(systemName: ic)
                                .frame(width: 36, height: 36)
                                .background(icon == ic ? Color.accentColor.opacity(0.2) : Color.clear,
                                            in: RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(icon == ic ? Color.accentColor : Color.secondary)
                                .onTapGesture { icon = ic }
                        }
                    }
                }
            }
            .navigationTitle("编辑分类")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        var updated = category
                        updated.name = name.trimmingCharacters(in: .whitespaces)
                        updated.icon = icon
                        if !updated.name.isEmpty {
                            vault.upsert(category: updated)
                        }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                name = category.name
                icon = category.icon
            }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 420)
        #endif
    }
}
