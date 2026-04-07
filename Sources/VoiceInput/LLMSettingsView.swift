import SwiftUI

struct LLMSettingsView: View {
    @State private var baseURL: String
    @State private var apiKey: String
    @State private var model: String
    @State private var status: String = ""
    @State private var isTesting = false

    private let settings = AppSettingsStore.shared
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        _baseURL = State(initialValue: AppSettingsStore.shared.apiBaseURL)
        _apiKey = State(initialValue: AppSettingsStore.shared.apiKey)
        _model = State(initialValue: AppSettingsStore.shared.model)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("OpenAI-compatible API")
                .font(.headline)

            LabeledContent("API Base URL") {
                TextField("https://api.openai.com/v1", text: $baseURL)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
            }

            LabeledContent("API Key") {
                SecureField("sk-…", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
            }

            LabeledContent("Model") {
                TextField("gpt-4o-mini", text: $model)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
            }

            if !status.isEmpty {
                Text(status)
                    .font(.callout)
                    .foregroundStyle(status.hasPrefix("Error") ? Color.red : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button("Test") {
                    Task { await runTest() }
                }
                .disabled(isTesting)

                Spacer()

                Button("Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)

                Button("Close") {
                    onClose()
                }
            }
        }
        .padding(20)
        .frame(minWidth: 400, minHeight: 260)
    }

    private func save() {
        settings.apiBaseURL = baseURL
        settings.model = model
        settings.setAPIKey(apiKey)
        status = "Saved."
    }

    private func runTest() async {
        isTesting = true
        status = ""
        let cfg = LLMConfig(apiBaseURL: baseURL, apiKey: apiKey, model: model)
        do {
            try await LLMRefinementService.testConnection(config: cfg)
            await MainActor.run {
                status = "Connection OK."
                isTesting = false
            }
        } catch {
            await MainActor.run {
                status = "Error: \(error.localizedDescription)"
                isTesting = false
            }
        }
    }
}
