import Foundation

/// 应用配置：持久化于 UserDefaults。仅保存非敏感信息（目录书签、超时时长等）。
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let defaults = UserDefaults.standard

    @Published var idleTimeoutSeconds: Int {
        didSet { defaults.set(idleTimeoutSeconds, forKey: "idleTimeoutSeconds") }
    }

    /// 用户选择的保存目录的 security-scoped 书签数据。为 nil 表示使用默认目录。
    @Published var vaultBookmark: Data? {
        didSet {
            if let vaultBookmark = vaultBookmark {
                defaults.set(vaultBookmark, forKey: "vaultBookmark")
            } else {
                defaults.removeObject(forKey: "vaultBookmark")
            }
        }
    }

    @Published var vaultFileName: String {
        didSet { defaults.set(vaultFileName, forKey: "vaultFileName") }
    }

    /// 默认保存目录（应用沙盒内）
    var defaultVaultDirectory: URL {
        let fm = FileManager.default
        #if os(macOS)
        if let url = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
            return url
        }
        return fm.homeDirectoryForCurrentUser
        #else
        if let url = try? fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
            return url
        }
        return fm.temporaryDirectory
        #endif
    }

    private init() {
        let d = UserDefaults.standard
        self.idleTimeoutSeconds = (d.object(forKey: "idleTimeoutSeconds") as? Int) ?? 120
        self.vaultBookmark = d.data(forKey: "vaultBookmark")
        self.vaultFileName = (d.string(forKey: "vaultFileName")) ?? "PasstoolVault.pst"
    }
}
