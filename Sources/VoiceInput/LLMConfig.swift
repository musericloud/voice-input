import Foundation

struct LLMConfig {
    var apiBaseURL: String
    var apiKey: String
    var model: String

    init(apiBaseURL: String, apiKey: String, model: String) {
        self.apiBaseURL = apiBaseURL
        self.apiKey = apiKey
        self.model = model
    }

    init(from settings: AppSettingsStore) {
        apiBaseURL = settings.apiBaseURL
        apiKey = settings.apiKey
        model = settings.model
    }
}
