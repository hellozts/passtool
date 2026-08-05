import Foundation

/// 磁盘读写 + security-scoped 书签解析。
enum VaultStore {

    /// 解析当前密码库文件 URL。
    /// - 书签存在：书签保存的是"目录"URL，返回 目录/文件名
    /// - 书签为空：返回 默认目录/文件名
    static func resolvedVaultURL() -> URL {
        if let bookmark = AppSettings.shared.vaultBookmark {
            var stale = false
            if var url = try? URL(resolvingBookmarkData: bookmark,
                                  options: [.withSecurityScope],
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &stale) {
                // 如果书签已过期，尝试刷新
                if stale {
                    #if os(macOS)
                    if let newBookmark = try? url.bookmarkData(options: [.withSecurityScope],
                                                               includingResourceValuesForKeys: nil,
                                                               relativeTo: nil) {
                        AppSettings.shared.vaultBookmark = newBookmark
                    }
                    #else
                    if let newBookmark = try? url.bookmarkData(options: [],
                                                                includingResourceValuesForKeys: nil,
                                                                relativeTo: nil) {
                        AppSettings.shared.vaultBookmark = newBookmark
                    }
                    #endif
                }
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
                   isDir.boolValue {
                    // 书签是目录，拼接文件名
                    url = url.appendingPathComponent(AppSettings.shared.vaultFileName)
                } else if !FileManager.default.fileExists(atPath: url.path) {
                    // 文件不存在：判断是否是目录（没有末尾 / 可能误判）
                    let (isDir2, existsDir) = directoryExistsAtPath(url.path)
                    if !existsDir && !url.lastPathComponent.contains(".") {
                        url = url.appendingPathComponent(AppSettings.shared.vaultFileName)
                    } else if isDir2 {
                        url = url.appendingPathComponent(AppSettings.shared.vaultFileName)
                    }
                }
                return url
            }
        }
        return AppSettings.shared.defaultVaultDirectory
            .appendingPathComponent(AppSettings.shared.vaultFileName)
    }

    private static func directoryExistsAtPath(_ path: String) -> (isDir: Bool, exists: Bool) {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        return (isDir.boolValue, exists)
    }

    /// 设置自定义保存目录（传入目录 URL）。生成 security-scoped 书签并保存。
    static func setVaultLocation(_ url: URL) {
        #if os(macOS)
        let options: URL.BookmarkCreationOptions = [.withSecurityScope]
        #else
        let options: URL.BookmarkCreationOptions = []
        #endif
        do {
            let bookmark = try url.bookmarkData(options: options,
                                                includingResourceValuesForKeys: nil,
                                                relativeTo: nil)
            AppSettings.shared.vaultBookmark = bookmark
        } catch {
            NSLog("[VaultStore] setVaultLocation bookmark create error: \(error)")
        }
    }

    static func clearVaultLocation() {
        AppSettings.shared.vaultBookmark = nil
    }

    // MARK: - 安全作用域包装

    /// 在 security-scoped 作用域内执行读操作。失败返回 nil。
    static func withReadAccess<T>(_ block: (URL) throws -> T) -> T? {
        let url = resolvedVaultURL()
        let scoped = beginAccess(url: url)
        defer { if scoped { endAccess(url: url) } }
        do {
            return try block(url)
        } catch {
            NSLog("[VaultStore] read error at \(url.path): \(error)")
            return nil
        }
    }

    /// 在 security-scoped 作用域内执行写操作，失败抛出错误。
    static func withWriteAccess(_ block: (URL) throws -> Void) throws {
        let url = resolvedVaultURL()
        let scoped = beginAccess(url: url)
        defer { if scoped { endAccess(url: url) } }
        do {
            try block(url)
        } catch {
            let ns = error as NSError
            let detail = "path=\(url.path), domain=\(ns.domain), code=\(ns.code): \(error.localizedDescription)"
            NSLog("[VaultStore] write error: \(detail)")
            throw VaultError.ioError(detail)
        }
    }

    private static func beginAccess(url: URL) -> Bool {
        guard AppSettings.shared.vaultBookmark != nil else { return false }
        let ok = url.startAccessingSecurityScopedResource()
        if !ok {
            NSLog("[VaultStore] startAccessingSecurityScopedResource returned false for \(url.path); proceeding anyway")
        }
        return ok
    }

    private static func endAccess(url: URL) {
        url.stopAccessingSecurityScopedResource()
    }

    // MARK: - 便捷接口

    static func vaultExists() -> Bool {
        withReadAccess { url in
            FileManager.default.fileExists(atPath: url.path)
        } ?? false
    }

    static func readVault() -> Data? {
        withReadAccess { url in
            try Data(contentsOf: url)
        }
    }

    static func writeVault(_ data: Data) throws {
        try withWriteAccess { url in
            // 确保父目录存在
            let parent = url.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: parent.path) {
                try FileManager.default.createDirectory(at: parent,
                                                        withIntermediateDirectories: true)
            }
            try data.write(to: url, options: .atomic)
        }
    }

    /// 删除密码库文件（用于重置）
    static func deleteVault() {
        _ = withReadAccess { url in
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - 附件目录（明文，不加密）

    /// 附件根目录名（位于密码库文件同级）
    static let attachmentsFolderName = "PasstoolAttachments"

    /// 返回附件根目录 URL（密码库文件同级目录下的 PasstoolAttachments/）。
    /// 注意：调用方需自行处理 security-scoped 访问（使用 withAttachmentAccess）。
    static func attachmentsDirectoryURL() -> URL {
        resolvedVaultURL().deletingLastPathComponent()
            .appendingPathComponent(attachmentsFolderName, isDirectory: true)
    }

    /// 返回某个条目的附件目录 URL。
    static func attachmentsDirectory(for entryID: UUID) -> URL {
        attachmentsDirectoryURL().appendingPathComponent(entryID.uuidString, isDirectory: true)
    }

    /// 在附件作用域内执行操作（基于密码库书签的安全作用域）。
    /// 附件目录与密码库文件在同一目录，复用其书签权限。
    static func withAttachmentAccess<T>(_ block: (URL) throws -> T) -> T? {
        let dir = attachmentsDirectoryURL()
        // 借用密码库文件所在目录的 security scope
        let vaultURL = resolvedVaultURL()
        let scoped = beginAccess(url: vaultURL)
        defer { if scoped { endAccess(url: vaultURL) } }
        do {
            return try block(dir)
        } catch {
            NSLog("[VaultStore] attachment access error at \(dir.path): \(error)")
            return nil
        }
    }
}
