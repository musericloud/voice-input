import Foundation

enum LLMRefinementError: Error {
    case invalidURL
    case http(Int, String?)
    case emptyResponse
}

extension LLMRefinementError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL or missing API key."
        case .http(let code, let body):
            return "HTTP \(code): \(body ?? "")"
        case .emptyResponse:
            return "Empty model response."
        }
    }
}

struct LLMRefinementService {
    private static let systemPrompt = """
    You are a speech-to-text post-processor. Process the input following these rules strictly in order:
    1. Fix obvious ASR errors: Chinese homophone mistakes, technical terms misrecognized across scripts (e.g. 配森→Python, 杰森→JSON, 吉特→Git).
    2. Add natural punctuation (，。？！、；：) if the input lacks it. Match punctuation style to the primary language.
    3. Remove oral filler words and verbal tics that add no meaning, such as: 嗯、啊、呃、哦、那个、就是、就是说、然后就是、对吧、你知道吗、basically、like、you know、um、uh. Only remove them when they are clearly fillers, not when they carry actual meaning in context.
    4. Lightly smooth overly colloquial phrasing into natural written style. For example: "我觉得这个东西它好像是不是有点问题" → "我觉得这个东西好像有点问题". Keep the author's original meaning, tone, and vocabulary. Do NOT rewrite into formal/literary style. The goal is readable casual writing, not an essay.
    5. Do NOT summarize, translate, expand, or add new content. Do NOT change technical terms, proper nouns, or numbers.
    If the input already reads well, return it EXACTLY unchanged.
    Output ONLY the final text. No quotes, no markdown, no explanations.
    """

    static func refine(_ transcript: String, settings: AppSettingsStore) async throws -> String {
        try await refine(transcript, config: LLMConfig(from: settings))
    }

    static func refine(_ transcript: String, config: LLMConfig) async throws -> String {
        let base = config.apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = chatCompletionsURL(from: base) else { throw LLMRefinementError.invalidURL }

        let key = config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw LLMRefinementError.invalidURL }

        let body = ChatRequest(
            model: config.model.trimmingCharacters(in: .whitespacesAndNewlines),
            messages: [
                ChatMessage(role: "system", content: Self.systemPrompt),
                ChatMessage(role: "user", content: transcript)
            ],
            temperature: 0
        )

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw LLMRefinementError.http(-1, nil) }
        guard (200 ... 299).contains(http.statusCode) else {
            let errText = String(data: data, encoding: .utf8)
            throw LLMRefinementError.http(http.statusCode, errText)
        }

        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        let text = decoded.choices?.first?.message?.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { throw LLMRefinementError.emptyResponse }
        return text
    }

    /// Test connectivity with a minimal request (does not mutate `AppSettingsStore`).
    static func testConnection(config: LLMConfig) async throws {
        _ = try await refine("ok", config: config)
    }

    private static func chatCompletionsURL(from base: String) -> URL? {
        var s = base
        if s.hasSuffix("/") { s.removeLast() }
        if !s.lowercased().hasSuffix("/chat/completions") {
            s += "/chat/completions"
        }
        return URL(string: s)
    }
}

private struct ChatRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
}

private struct ChatMessage: Encodable {
    let role: String
    let content: String
}

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Msg: Decodable {
            let content: String?
        }
        let message: Msg?
    }
    let choices: [Choice]?
}
