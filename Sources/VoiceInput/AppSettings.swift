import Foundation

final class AppSettingsStore {
    static let shared = AppSettingsStore()

    private let defaults = UserDefaults.standard

    private init() {
        if defaults.string(forKey: Keys.apiKey) == nil,
           let legacy = KeychainStore.load() {
            defaults.set(legacy, forKey: Keys.apiKey)
            KeychainStore.delete()
        }
    }

    private enum Keys {
        static let language = "voiceInput.language"
        static let llmEnabled = "voiceInput.llmEnabled"
        static let apiBaseURL = "voiceInput.apiBaseURL"
        static let apiKey = "voiceInput.apiKey"
        static let model = "voiceInput.model"
    }

    var voiceLanguage: VoiceLanguage {
        get {
            guard let raw = defaults.string(forKey: Keys.language),
                  let v = VoiceLanguage(rawValue: raw) else {
                return .default
            }
            return v
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.language) }
    }

    var llmRefinementEnabled: Bool {
        get { defaults.object(forKey: Keys.llmEnabled) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Keys.llmEnabled) }
    }

    var apiBaseURL: String {
        get {
            let v = defaults.string(forKey: Keys.apiBaseURL)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return v.isEmpty ? "https://api.openai.com/v1" : v
        }
        set { defaults.set(newValue, forKey: Keys.apiBaseURL) }
    }

    var model: String {
        get {
            let v = defaults.string(forKey: Keys.model)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return v.isEmpty ? "gpt-4o-mini" : v
        }
        set { defaults.set(newValue, forKey: Keys.model) }
    }

    var apiKey: String {
        get { defaults.string(forKey: Keys.apiKey) ?? "" }
        set { defaults.set(newValue, forKey: Keys.apiKey) }
    }

    func setAPIKey(_ key: String) {
        apiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isLLMConfigured: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
