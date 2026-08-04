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

    init(id: UUID = UUID(),
         title: String = "",
         username: String = "",
         password: String = "",
         url: String = "",
         notes: String = "",
         categoryID: UUID? = nil,
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.username = username
        self.password = password
        self.url = url
        self.notes = notes
        self.categoryID = categoryID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// 密码库明文数据结构（加密前 / 解密后）
struct VaultData: Codable {
    var version: Int
    var entries: [VaultEntry]
    var categories: [VaultCategory]
}
