import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// 附件存储管理：图片和附件明文存储于密码库同级的 PasstoolAttachments/<entryID>/ 目录。
/// 不参与加密，仅通过文件名/元信息与条目关联。
enum AttachmentStore {

    /// 保存图片数据，返回生成的文件名（含扩展名）。
    @discardableResult
    static func saveImage(data: Data, ext: String, entryID: UUID) -> String? {
        let fileName = "\(UUID().uuidString).\(ext)"
        guard let url = resolveFileURL(entryID: entryID, fileName: fileName) else { return nil }
        do {
            try ensureDirectory(for: entryID)
            try data.write(to: url, options: .atomic)
            return fileName
        } catch {
            NSLog("[AttachmentStore] saveImage error: \(error)")
            return nil
        }
    }

    /// 从源 URL 复制文件作为附件，返回附件元信息。
    @discardableResult
    static func saveAttachment(from sourceURL: URL, entryID: UUID) -> VaultAttachment? {
        let ext = sourceURL.pathExtension.isEmpty ? "bin" : sourceURL.pathExtension
        let fileName = "\(UUID().uuidString).\(ext)"
        let originalName = sourceURL.lastPathComponent
        do {
            try ensureDirectory(for: entryID)
            guard let destDir = VaultStore.withAttachmentAccess({ $0 })?
                .appendingPathComponent(entryID.uuidString, isDirectory: true) else {
                return nil
            }
            let dest = destDir.appendingPathComponent(fileName)
            try FileManager.default.copyItem(at: sourceURL, to: dest)
            let size = (try? FileManager.default.attributesOfItem(atPath: dest.path)[.size] as? Int64) ?? 0
            return VaultAttachment(fileName: fileName, originalName: originalName, size: size)
        } catch {
            NSLog("[AttachmentStore] saveAttachment error: \(error)")
            return nil
        }
    }

    /// 返回图片文件 URL（已处于安全作用域内读取）。
    static func imageURL(entryID: UUID, fileName: String) -> URL? {
        resolveFileURL(entryID: entryID, fileName: fileName)
    }

    /// 加载图片数据用于显示。
    static func loadImage(entryID: UUID, fileName: String) -> Data? {
        guard let url = resolveFileURL(entryID: entryID, fileName: fileName) else { return nil }
        return try? Data(contentsOf: url)
    }

    /// 删除单个图片。
    static func deleteImage(entryID: UUID, fileName: String) {
        guard let url = resolveFileURL(entryID: entryID, fileName: fileName) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// 删除单个附件文件。
    static func deleteAttachmentFile(entryID: UUID, fileName: String) {
        guard let url = resolveFileURL(entryID: entryID, fileName: fileName) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// 删除某个条目的全部附件目录。
    static func deleteAll(for entryID: UUID) {
        _ = VaultStore.withAttachmentAccess { root in
            let dir = root.appendingPathComponent(entryID.uuidString, isDirectory: true)
            try? FileManager.default.removeItem(at: dir)
        }
    }

    // MARK: - 私有

    /// 在安全作用域内解析附件文件 URL。
    private static func resolveFileURL(entryID: UUID, fileName: String) -> URL? {
        VaultStore.withAttachmentAccess { root in
            root.appendingPathComponent(entryID.uuidString, isDirectory: true)
                .appendingPathComponent(fileName)
        }
    }

    /// 确保条目附件目录存在。
    private static func ensureDirectory(for entryID: UUID) throws {
        guard let dir = VaultStore.withAttachmentAccess({ $0 })?
            .appendingPathComponent(entryID.uuidString, isDirectory: true) else {
            throw NSError(domain: "AttachmentStore", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "无法访问附件目录"])
        }
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    /// 将字节数格式化为可读字符串。
    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

#if os(macOS)
/// macOS 图片选择器（NSOpenPanel）
struct ImagePicker: NSViewRepresentable {
    let entryID: UUID
    let onPicked: (String) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { pick(context: context) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private func pick(context: Context) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.png, .jpeg, .image, .gif, .tiff, .bmp]
        panel.title = "选择图片"
        if panel.runModal() == .OK {
            for url in panel.urls {
                if let data = try? Data(contentsOf: url) {
                    let ext = url.pathExtension.lowercased()
                    let validExt = ["png", "jpg", "jpeg", "gif", "tiff", "bmp", "heic"].contains(ext) ? ext : "png"
                    if let name = AttachmentStore.saveImage(data: data, ext: validExt, entryID: entryID) {
                        onPicked(name)
                    }
                }
            }
        }
    }
}

/// macOS 附件文件选择器
struct AttachmentPicker: NSViewRepresentable {
    let entryID: UUID
    let onPicked: (VaultAttachment) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { pick(context: context) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private func pick(context: Context) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = "选择附件"
        if panel.runModal() == .OK {
            for url in panel.urls {
                if let att = AttachmentStore.saveAttachment(from: url, entryID: entryID) {
                    onPicked(att)
                }
            }
        }
    }
}
#endif
