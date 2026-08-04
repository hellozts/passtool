import Foundation

/// 随机密码生成器
enum PasswordGenerator {

    struct Options {
        var length: Int = 20
        var useLowercase: Bool = true
        var useUppercase: Bool = true
        var useDigits: Bool = true
        var useSymbols: Bool = true
    }

    private static let lowercase = "abcdefghijkmnopqrstuvwxyz"
    private static let uppercase = "ABCDEFGHJKLMNPQRSTUVWXYZ"
    private static let digits = "23456789"
    private static let symbols = "!@#$%^&*-_=+?"

    static func generate(_ options: Options = Options()) -> String {
        var pool = ""
        if options.useLowercase { pool += lowercase }
        if options.useUppercase { pool += uppercase }
        if options.useDigits { pool += digits }
        if options.useSymbols { pool += symbols }
        guard !pool.isEmpty else { return "" }

        let len = max(4, min(64, options.length))
        var result = ""
        let chars = Array(pool)
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<len {
            result.append(chars.randomElement(using: &rng)!)
        }
        return result
    }

    /// 强度评估（0-4）
    static func strength(_ password: String) -> Int {
        let len = password.count
        var score = 0
        if len >= 8 { score += 1 }
        if len >= 12 { score += 1 }
        if len >= 16 { score += 1 }
        let hasLower = password.rangeOfCharacter(from: .lowercaseLetters) != nil
        let hasUpper = password.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasDigit = password.rangeOfCharacter(from: .decimalDigits) != nil
        let hasSymbol = password.rangeOfCharacter(from: .symbols) != nil
        let variety = [hasLower, hasUpper, hasDigit, hasSymbol].filter { $0 }.count
        if variety >= 3 { score += 1 }
        if variety == 4 && len >= 12 { score = max(score, 4) }
        return min(4, score)
    }

    static func strengthLabel(_ score: Int) -> String {
        switch score {
        case 0: return "非常弱"
        case 1: return "弱"
        case 2: return "一般"
        case 3: return "强"
        default: return "非常强"
        }
    }
}
