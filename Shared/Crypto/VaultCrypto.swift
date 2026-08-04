import Foundation
import CryptoKit
import CommonCrypto

/// 加密后的密码库文件结构（JSON 持久化）
struct EncryptedBlob: Codable {
    let version: Int
    let salt: Data
    let iterations: Int
    /// AES-GCM SealedBox 的 combined 表示（nonce + ciphertext + tag）
    let box: Data
}

/// 加密工具：PBKDF2(SHA256) 派生密钥 + AES-256-GCM 加解密
enum VaultCrypto {
    static let iterations = 600_000
    static let version = 1

    /// 生成 32 字节随机盐
    static func makeSalt() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes 失败")
        return Data(bytes)
    }

    /// 使用 PBKDF2-HMAC-SHA256 从主密码派生 256 位密钥
    static func deriveKey(password: String, salt: Data, iterations: Int) -> SymmetricKey {
        var derived = Data(count: 32)
        let status = derived.withUnsafeMutableBytes { (derivedPtr: UnsafeMutableRawBufferPointer) -> Int32 in
            salt.withUnsafeBytes { (saltPtr: UnsafeRawBufferPointer) -> Int32 in
                password.withCString { (cstr: UnsafePointer<CChar>) -> Int32 in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        cstr, strlen(cstr),
                        saltPtr.bindMemory(to: UInt8.self).baseAddress, salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        derivedPtr.bindMemory(to: UInt8.self).baseAddress, 32
                    )
                }
            }
        }
        precondition(status == kCCSuccess, "CCKeyDerivationPBKDF 失败")
        return SymmetricKey(data: derived)
    }

    /// AES-GCM 加密，返回 combined（nonce+密文+tag）
    static func seal(_ plaintext: Data, key: SymmetricKey) throws -> Data {
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else { throw VaultError.encryptionFailed }
        return combined
    }

    /// AES-GCM 解密
    static func open(_ combined: Data, key: SymmetricKey) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: combined)
        return try AES.GCM.open(box, using: key)
    }
}

enum VaultError: Error, LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case wrongPassword
    case ioError(String)
    case notUnlocked
    case invalidState
    case weakPassword

    var errorDescription: String? {
        switch self {
        case .encryptionFailed: return "加密失败"
        case .decryptionFailed: return "解密失败"
        case .wrongPassword: return "主密码错误"
        case .ioError(let msg): return "文件错误：\(msg)"
        case .notUnlocked: return "密码库未解锁"
        case .invalidState: return "当前状态不允许该操作"
        case .weakPassword: return "主密码至少 4 位"
    }
}
}
