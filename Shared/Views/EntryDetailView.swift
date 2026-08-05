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

                if !entry.imageFileNames.isEmpty {
                    Divider()
                    ImagesSection(entryID: entry.id, fileNames: entry.imageFileNames)
                }

                if !entry.attachments.isEmpty {
                    Divider()
                    AttachmentsSection(entryID: entry.id, attachments: entry.attachments)
                }

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

/// 图片展示区（可点击放大查看）
struct ImagesSection: View {
    let entryID: UUID
    let fileNames: [String]
    @State private var previewIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("图片")
                .font(.caption)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(Array(fileNames.enumerated()), id: \.element) { idx, name in
                    Group {
                        if let data = AttachmentStore.loadImage(entryID: entryID, fileName: name),
                           let nsImage = NSImage(data: data) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Rectangle().fill(.secondary.opacity(0.1))
                                .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                        }
                    }
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onTapGesture { previewIndex = idx }
                }
            }
        }
        #if os(macOS)
        .sheet(item: Binding(
            get: { previewIndex.map { IdentifiableInt(value: $0) } },
            set: { previewIndex = $0?.value }
        )) { item in
            ImagePreviewSheet(entryID: entryID, fileNames: fileNames, index: item.value)
        }
        #endif
    }
}

/// 附件展示区（可双击在 Finder 中显示 / 保存到下载）
struct AttachmentsSection: View {
    let entryID: UUID
    let attachments: [VaultAttachment]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("附件")
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(spacing: 2) {
                ForEach(attachments) { att in
                    HStack {
                        Image(systemName: icon(for: att.originalName))
                            .foregroundStyle(.tint)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(att.originalName)
                                .lineLimit(1).truncationMode(.middle)
                            Text(AttachmentStore.formatBytes(att.size))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            revealAttachment(att)
                        } label: {
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        Button {
                            saveAttachment(att)
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { revealAttachment(att) }
                }
            }
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func icon(for name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.richtext"
        case "txt", "md", "rtf": return "doc.text"
        case "zip", "rar", "7z", "gz": return "doc.zipper"
        case "mp3", "wav", "m4a", "aac", "flac": return "waveform"
        case "mp4", "mov", "avi", "mkv": return "film"
        case "jpg", "jpeg", "png", "gif", "heic", "tiff", "bmp": return "photo"
        case "doc", "docx": return "doc.fill"
        case "xls", "xlsx", "csv": return "chart.bar.doc.horizontal"
        case "ppt", "pptx": return "doc.text.image"
        default: return "doc"
        }
    }

    private func revealAttachment(_ att: VaultAttachment) {
        guard let url = AttachmentStore.imageURL(entryID: entryID, fileName: att.fileName) else { return }
        #if os(macOS)
        NSWorkspace.shared.activateFileViewerSelecting([url])
        #endif
    }

    private func saveAttachment(_ att: VaultAttachment) {
        guard let url = AttachmentStore.imageURL(entryID: entryID, fileName: att.fileName) else { return }
        #if os(macOS)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = att.originalName
        if panel.runModal() == .OK, let dest = panel.url {
            try? FileManager.default.copyItem(at: url, to: dest)
        }
        #endif
    }
}

#if os(macOS)
/// 图片大图预览
struct ImagePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let entryID: UUID
    let fileNames: [String]
    let index: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(index + 1) / \(fileNames.count)")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("完成") { dismiss() }
            }
            .padding()
            Divider()
            if let data = AttachmentStore.loadImage(entryID: entryID, fileName: fileNames[index]),
               let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .padding()
            } else {
                Text("无法加载图片").foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}
#endif

/// 用于 sheet item 的 Int 包装
private struct IdentifiableInt: Identifiable {
    let value: Int
    var id: Int { value }
}
