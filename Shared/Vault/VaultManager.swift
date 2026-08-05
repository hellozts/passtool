import Foundation
import CryptoKit
import Combine

@MainActor
enum VaultState: Equatable {
    case needsSetup   // 未创建密码库
    case locked       // 已存在，待解锁
    case unlocked     // 已解锁
}

/// 密码库核心管理器：解锁 / 锁定 / 增删改查 / 修改主密码。
@MainActor
final class VaultManager: ObservableObject {
    static let shared = VaultManager()

    @Published var state: VaultState = .locked
    @Published var data: VaultData = VaultData(version: VaultCrypto.version, entries: [], categories: [])
    @Published var lastError: String?

    /// 仅在内存中保存派生密钥与盐；主密码本身不保留。
    private var key: SymmetricKey?
    private var salt: Data?
    private var iterations: Int = VaultCrypto.iterations

    private init() {
        refreshState()
    }

    // MARK: - 状态

    func refreshState() {
        key = nil
        salt = nil
        data = VaultData(version: VaultCrypto.version, entries: [], categories: [])
        state = VaultStore.vaultExists() ? .locked : .needsSetup
    }

    var isUnlocked: Bool { state == .unlocked }

    // MARK: - 创建 / 解锁 / 锁定

    /// 首次创建密码库
    func createVault(masterPassword: String) throws {
        guard masterPassword.count >= 4 else { throw VaultError.weakPassword }
        let newSalt = VaultCrypto.makeSalt()
        let newKey = VaultCrypto.deriveKey(password: masterPassword, salt: newSalt, iterations: iterations)
        data = VaultData(version: VaultCrypto.version, entries: [], categories: defaultCategories())
        NSLog("[VaultManager] createVault: default categories=\(data.categories.map { $0.name })")
        self.key = newKey
        self.salt = newSalt
        try persist()
        state = .unlocked
    }

    /// 使用主密码解锁。成功返回 true。
    @discardableResult
    func unlock(masterPassword: String) -> Bool {
        guard let raw = VaultStore.readVault() else {
            lastError = "无法读取密码库文件"
            return false
        }
        do {
            let blob = try JSONDecoder().decode(EncryptedBlob.self, from: raw)
            let k = VaultCrypto.deriveKey(password: masterPassword, salt: blob.salt, iterations: blob.iterations)
            let plain = try VaultCrypto.open(blob.box, key: k) // 密码错误会抛错
            self.data = try JSONDecoder().decode(VaultData.self, from: plain)
            NSLog("[VaultManager] unlock OK: entries=\(data.entries.count), categories=\(data.categories.count)")
            self.key = k
            self.salt = blob.salt
            self.iterations = blob.iterations
            self.lastError = nil
            state = .unlocked
            return true
        } catch {
            lastError = "主密码错误或数据已损坏"
            return false
        }
    }

    func lock() {
        key = nil
        salt = nil
        data = VaultData(version: VaultCrypto.version, entries: [], categories: [])
        state = VaultStore.vaultExists() ? .locked : .needsSetup
    }

    // MARK: - 持久化

    private func persist() throws {
        guard let key = key, let salt = salt else { throw VaultError.notUnlocked }
        let plain = try JSONEncoder().encode(data)
        let box = try VaultCrypto.seal(plain, key: key)
        let blob = EncryptedBlob(version: VaultCrypto.version, salt: salt, iterations: iterations, box: box)
        let raw = try JSONEncoder().encode(blob)
        try VaultStore.writeVault(raw)
    }

    func save() {
        do {
            try persist()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - 条目 CRUD

    func upsert(entry: VaultEntry) {
        var e = entry
        e.updatedAt = Date()
        if let idx = data.entries.firstIndex(where: { $0.id == e.id }) {
            e.createdAt = data.entries[idx].createdAt
            data.entries[idx] = e
        } else {
            data.entries.append(e)
        }
        save()
    }

    func delete(entry: VaultEntry) {
        data.entries.removeAll { $0.id == entry.id }
        // 清理该条目的图片和附件文件（明文存储，不加密）
        AttachmentStore.deleteAll(for: entry.id)
        save()
    }

    // MARK: - 分类 CRUD

    func upsert(category: VaultCategory) {
        if let idx = data.categories.firstIndex(where: { $0.id == category.id }) {
            data.categories[idx] = category
        } else {
            data.categories.append(category)
        }
        save()
    }

    func deleteCategory(_ category: VaultCategory) {
        data.categories.removeAll { $0.id == category.id }
        for i in data.entries.indices where data.entries[i].categoryID == category.id {
            data.entries[i].categoryID = nil
        }
        save()
    }

    func categoryName(for id: UUID?) -> String {
        guard let id = id, let c = data.categories.first(where: { $0.id == id }) else { return "未分类" }
        return c.name
    }

    func categoryIcon(for id: UUID?) -> String {
        guard let id = id, let c = data.categories.first(where: { $0.id == id }) else { return "tray" }
        return c.icon
    }

    // MARK: - 修改主密码

    func changeMasterPassword(current: String, new: String) throws {
        guard state == .unlocked, let salt = salt else { throw VaultError.invalidState }
        guard new.count >= 4 else { throw VaultError.weakPassword }
        // 验证当前密码：用当前密码重新派生并尝试解密原文件
        guard let raw = VaultStore.readVault(),
              let blob = try? JSONDecoder().decode(EncryptedBlob.self, from: raw) else {
            throw VaultError.ioError("读取密码库失败")
        }
        let verifyKey = VaultCrypto.deriveKey(password: current, salt: salt, iterations: iterations)
        _ = try VaultCrypto.open(blob.box, key: verifyKey) // 密码错误会抛错

        let newSalt = VaultCrypto.makeSalt()
        let newKey = VaultCrypto.deriveKey(password: new, salt: newSalt, iterations: iterations)
        self.key = newKey
        self.salt = newSalt
        try persist()
    }

    /// 重置（删除）整个密码库
    func resetVault() {
        VaultStore.deleteVault()
        lock()
        refreshState()
    }

    // MARK: - 默认分类

    private func defaultCategories() -> [VaultCategory] {
        [
            VaultCategory(name: "登录账号", icon: "lock.shield"),
            VaultCategory(name: "财务支付", icon: "creditcard"),
            VaultCategory(name: "安全备注", icon: "note.text"),
            VaultCategory(name: "其他", icon: "tray")
        ]
    }
}
