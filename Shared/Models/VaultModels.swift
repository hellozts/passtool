import Foundation

/// 密码库分类
struct VaultCategory: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    /// SF Symbol 图标名称
    var icon: String

    init(id: UUID = UUID(), name: String, icon: String = "tray") {
        self.id = id
        self.name = name
        self.icon = icon
    }
}

/// 单条密码条目
struct VaultEntry: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
    var username: String
    var password: String
    var url: String
    var notes: String
    var categoryID: UUID?
    var createdAt: Date
    var updatedAt: Date
    /// 关联图片文件名列表（明文存储于附件目录，不参与加密）
    var imageFileNames: [String]
    /// 关联附件列表（明文存储于附件目录，不参与加密）
    var attachments: [VaultAttachment]

    init(id: UUID = UUID(),
         title: String = "",
         username: String = "",
         password: String = "",
         url: String = "",
         notes: String = "",
         categoryID: UUID? = nil,
         createdAt: Date = Date(),
         updatedAt: Date = Date(),
         imageFileNames: [String] = [],
         attachments: [VaultAttachment] = []) {
        self.id = id
        self.title = title
        self.username = username
        self.password = password
        self.url = url
        self.notes = notes
        self.categoryID = categoryID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.imageFileNames = imageFileNames
        self.attachments = attachments
    }

    /// 兼容旧版本数据：解码时若缺少新字段则填默认值
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        username = try c.decode(String.self, forKey: .username)
        password = try c.decode(String.self, forKey: .password)
        url = try c.decode(String.self, forKey: .url)
        notes = try c.decode(String.self, forKey: .notes)
        categoryID = try c.decodeIfPresent(UUID.self, forKey: .categoryID)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        imageFileNames = try c.decodeIfPresent([String].self, forKey: .imageFileNames) ?? []
        attachments = try c.decodeIfPresent([VaultAttachment].self, forKey: .attachments) ?? []
    }
}

/// 附件元信息（文件本身明文存储，不加密）
struct VaultAttachment: Codable, Identifiable, Hashable {
    var id: UUID
    /// 磁盘文件名（UUID + 扩展名）
    var fileName: String
    /// 原始文件名（展示用）
    var originalName: String
    /// 文件大小（字节）
    var size: Int64

    init(id: UUID = UUID(), fileName: String, originalName: String, size: Int64) {
        self.id = id
        self.fileName = fileName
        self.originalName = originalName
        self.size = size
    }
}

/// 密码库明文数据结构（加密前 / 解密后）
struct VaultData: Codable {
    var version: Int
    var entries: [VaultEntry]
    var categories: [VaultCategory]
}
