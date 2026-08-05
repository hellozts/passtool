import SwiftUI

/// 新建 / 编辑条目
struct EntryEditorView: View {
    @ObservedObject var vault = VaultManager.shared
    @Environment(\.dismiss) private var dismiss

    let entry: VaultEntry?

    @State private var title = ""
    @State private var username = ""
    @State private var password = ""
    @State private var url = ""
    @State private var notes = ""
    @State private var categoryID: UUID?
    @State private var showPassword = false
    @State private var showGenerator = false
    @State private var imageFileNames: [String] = []
    @State private var attachments: [VaultAttachment] = []
    @State private var pickImage = false
    @State private var pickAttachment = false
    @State private var workingEntryID: UUID = UUID()

    private var entryID: UUID { entry?.id ?? workingEntryID }
    private var isEditing: Bool { entry != nil }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("基本信息") {
                    TextField("标题", text: $title)
                    TextField("用户名 / 邮箱", text: $username)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif

                    VStack(alignment: .leading) {
                        HStack {
                            if showPassword {
                                TextField("密码", text: $password)
                                    #if os(iOS)
                                    .textInputAutocapitalization(.never)
                                    #endif
                            } else {
                                SecureField("密码", text: $password)
                            }
                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                            Button {
                                showGenerator = true
                            } label: {
                                Image(systemName: "wand.and.stars")
                                    .foregroundStyle(.tint)
                            }
                            .buttonStyle(.borderless)
                        }
                        if !password.isEmpty {
                            StrengthBar(score: PasswordGenerator.strength(password))
                        }
                    }

                    Picker("分类", selection: $categoryID) {
                        Text("未分类").tag(UUID?.none)
                        ForEach(vault.data.categories) { c in
                            Label(c.name, systemImage: c.icon).tag(Optional(c.id))
                        }
                    }
                }

                Section("其他") {
                    TextField("网址", text: $url)
                        #if os(iOS)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        #endif
                    TextField("备注", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("图片（不加密）") {
                    if !imageFileNames.isEmpty {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                            ForEach(imageFileNames, id: \.self) { name in
                                imageThumbnail(name: name)
                            }
                        }
                    }
                    Button {
                        pickImage = true
                    } label: {
                        Label("添加图片", systemImage: "photo.on.rectangle")
                    }
                }

                Section("附件（不加密）") {
                    if !attachments.isEmpty {
                        ForEach(attachments) { att in
                            HStack {
                                Image(systemName: attachmentIcon(for: att.originalName))
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading) {
                                    Text(att.originalName).lineLimit(1).truncationMode(.middle)
                                    Text(AttachmentStore.formatBytes(att.size))
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    attachments.removeAll { $0.id == att.id }
                                    AttachmentStore.deleteAttachmentFile(entryID: entryID, fileName: att.fileName)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    Button {
                        pickAttachment = true
                    } label: {
                        Label("添加附件", systemImage: "paperclip")
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("取消", role: .cancel) { dismiss() }
                Spacer()
                Button(isEditing ? "保存" : "添加") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .navigationTitle(isEditing ? "编辑条目" : "新建条目")
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 460)
        #endif
        .onAppear { load() }
        .sheet(isPresented: $showGenerator) {
            PasswordGeneratorSheet(password: $password)
        }
        #if os(macOS)
        .background(
            Group {
                if pickImage {
                    ImagePicker(entryID: entryID) { name in
                        imageFileNames.append(name)
                        pickImage = false
                    }
                    .frame(width: 0, height: 0)
                }
                if pickAttachment {
                    AttachmentPicker(entryID: entryID) { att in
                        attachments.append(att)
                        pickAttachment = false
                    }
                    .frame(width: 0, height: 0)
                }
            }
            .opacity(0)
        )
        #endif
    }

    private func load() {
        guard let e = entry else { return }
        title = e.title
        username = e.username
        password = e.password
        url = e.url
        notes = e.notes
        categoryID = e.categoryID
        imageFileNames = e.imageFileNames
        attachments = e.attachments
    }

    private func save() {
        var e = entry ?? VaultEntry(id: workingEntryID)
        // 新建条目时：workingEntryID 已用于存放附件，直接复用该 ID
        e.title = title.trimmingCharacters(in: .whitespaces)
        e.username = username
        e.password = password
        e.url = url
        e.notes = notes
        e.categoryID = categoryID
        e.imageFileNames = imageFileNames
        e.attachments = attachments
        vault.upsert(entry: e)
        dismiss()
    }

    // MARK: - 图片缩略图

    @ViewBuilder
    private func imageThumbnail(name: String) -> some View {
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
        .frame(height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .topTrailing) {
            Button {
                imageFileNames.removeAll { $0 == name }
                AttachmentStore.deleteImage(entryID: entryID, fileName: name)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white, .black.opacity(0.5))
                    .font(.system(size: 16))
            }
            .buttonStyle(.borderless)
            .padding(4)
        }
    }

    private func attachmentIcon(for name: String) -> String {
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
}

/// 密码生成器弹窗
struct PasswordGeneratorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var password: String

    @State private var length: Double = 20
    @State private var useUpper = true
    @State private var useLower = true
    @State private var useDigits = true
    @State private var useSymbols = true

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Text("密码生成器").font(.headline)
                Spacer()
                Button("完成") { dismiss() }.buttonStyle(.borderedProminent)
            }

            let pwd = PasswordGenerator.generate(.init(length: Int(length),
                                                       useLowercase: useLower,
                                                       useUppercase: useUpper,
                                                       useDigits: useDigits,
                                                       useSymbols: useSymbols))
            Text(pwd)
                .font(.body.monospaced())
                .padding()
                .frame(maxWidth: .infinity)
                .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                .textSelection(.enabled)

            StrengthBar(score: PasswordGenerator.strength(pwd))

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("长度：\(Int(length))")
                    Spacer()
                }
                Slider(value: $length, in: 8...48, step: 1)
                Toggle("大写字母 (A-Z)", isOn: $useUpper)
                Toggle("小写字母 (a-z)", isOn: $useLower)
                Toggle("数字 (0-9)", isOn: $useDigits)
                Toggle("符号 (!@#$)", isOn: $useSymbols)
            }

            HStack {
                Button("重新生成") {
                    password = PasswordGenerator.generate(.init(length: Int(length),
                                                                useLowercase: useLower,
                                                                useUppercase: useUpper,
                                                                useDigits: useDigits,
                                                                useSymbols: useSymbols))
                }
                Spacer()
                Button("使用此密码") {
                    password = pwd
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        #if os(macOS)
        .frame(width: 420)
        #endif
    }
}
