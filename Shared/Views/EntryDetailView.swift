import SwiftUI

/// 条目详情：密码默认隐藏，可显示 / 复制
struct EntryDetailView: View {
    @ObservedObject var vault = VaultManager.shared
    let entry: VaultEntry

    @State private var showPassword = false
    @State private var showEditor = false
    @State private var copiedField: String?
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                Divider()

                InfoRow(label: "用户名", value: entry.username, copyable: !entry.username.isEmpty, copiedField: $copiedField)
                PasswordRow(value: entry.password, showPassword: $showPassword, copiedField: $copiedField)
                InfoRow(label: "网址", value: entry.url, copyable: !entry.url.isEmpty, copiedField: $copiedField, link: true)
                InfoRow(label: "备注", value: entry.notes, copyable: false, copiedField: $copiedField, multiline: true)

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    metaRow("分类", vault.categoryName(for: entry.categoryID))
                    metaRow("创建时间", entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                    metaRow("更新时间", entry.updatedAt.formatted(date: .abbreviated, time: .shortened))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(entry.title.isEmpty ? "条目" : entry.title)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showEditor = true
                } label: {
                    Label("编辑", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            EntryEditorView(entry: entry)
        }
        .confirmationDialog("确定删除「\(entry.title.isEmpty ? "未命名" : entry.title)」？",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                vault.delete(entry: entry)
            }
            Button("取消", role: .cancel) {}
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: vault.categoryIcon(for: entry.categoryID))
                .font(.system(size: 30))
                .foregroundStyle(.tint)
                .frame(width: 48, height: 48)
                .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title.isEmpty ? "(未命名)" : entry.title)
                    .font(.title2.bold())
                Text(vault.categoryName(for: entry.categoryID))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func metaRow(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).frame(width: 70, alignment: .leading)
            Text(v)
        }
    }
}

/// 普通信息行（可复制）
struct InfoRow: View {
    let label: String
    let value: String
    let copyable: Bool
    @Binding var copiedField: String?
    var link: Bool = false
    var multiline: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .top) {
                if multiline {
                    Text(value.isEmpty ? "—" : value)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(value.isEmpty ? "—" : value)
                        .font(.body)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    Spacer()
                }
                if copyable {
                    CopyButton {
                        Clipboard.copy(value)
                        copiedField = label
                    }
                }
            }
        }
    }
}

/// 密码行：默认隐藏，可显示 / 复制
struct PasswordRow: View {
    let value: String
    @Binding var showPassword: Bool
    @Binding var copiedField: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("密码")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                if showPassword {
                    Text(value.isEmpty ? "—" : value)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                } else {
                    Text(value.isEmpty ? "—" : String(repeating: "•", count: max(6, min(16, value.count))))
                        .font(.body.monospaced())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !value.isEmpty {
                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                    #if os(macOS)
                    .help(showPassword ? "隐藏密码" : "显示密码")
                    #endif

                    CopyButton {
                        Clipboard.copy(value)
                        copiedField = "密码"
                    }
                }
            }
            if !value.isEmpty {
                StrengthBar(score: PasswordGenerator.strength(value))
                    .padding(.top, 2)
            }
        }
    }
}

/// 复制按钮（带短暂"已复制"反馈）
struct CopyButton: View {
    @State private var copied = false
    let action: () -> Void

    var body: some View {
        Button {
            action()
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
        } label: {
            Label(copied ? "已复制" : "复制", systemImage: copied ? "checkmark" : "doc.on.doc")
                .font(.caption)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}
