import Foundation

enum VoiceLanguage: String, CaseIterable, Codable {
    case english = "en-US"
    case chineseSimplified = "zh-CN"
    case chineseTraditional = "zh-TW"
    case japanese = "ja-JP"
    case korean = "ko-KR"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .chineseSimplified: return "简体中文"
        case .chineseTraditional: return "繁體中文"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }

    static var `default`: VoiceLanguage { .chineseSimplified }
}
