import AppKit
import AVFoundation
import Speech

final class RecordingController {
    private let overlay = RecordingOverlayPanel()
    private let settings = AppSettingsStore.shared

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?

    private var lastPartial = ""
    private var lastRMS: Float = 0
    private let weights: [Float] = [0.4, 0.6, 0.85, 1.0, 0.8, 0.55, 0.35]
    private let attack: Float = 0.4
    private let release: Float = 0.15

    private var isRecording = false
    private var sessionGeneration = 0

    func start() {
        guard !isRecording else { return }
        isRecording = true
        sessionGeneration += 1
        let gen = sessionGeneration

        lastPartial = ""
        lastRMS = 0
        overlay.show()
        overlay.setState(.recording)

        Task {
            let mic = await Self.requestMicrophonePermission()
            let speech = await Self.requestSpeechAuthorization()
            guard gen == self.sessionGeneration else { return }
            guard mic, speech else {
                await MainActor.run {
                    self.overlay.updateTranscript("需要麦克风与语音识别权限。")
                    self.overlay.hide()
                    self.isRecording = false
                }
                return
            }
            await MainActor.run {
                guard gen == self.sessionGeneration else { return }
                self.beginEngineAndSpeech()
            }
        }
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false
        sessionGeneration += 1

        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        let text = lastPartial.trimmingCharacters(in: .whitespacesAndNewlines)

        Task { await self.finalize(text: text) }
    }

    private func beginEngineAndSpeech() {
        let locale = Locale(identifier: settings.voiceLanguage.rawValue)
        guard let sr = SFSpeechRecognizer(locale: locale), sr.isAvailable else {
            overlay.updateTranscript("当前语言不可用或语音识别未就绪。")
            return
        }
        speechRecognizer = sr

        let engine = AVAudioEngine()
        audioEngine = engine

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        request.addsPunctuation = true
        recognitionRequest = request

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            self?.processRMS(buffer)
        }

        recognitionTask = sr.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.lastPartial = text
                    self.overlay.updateTranscript(text)
                }
            }
            if error != nil {
                // Finalization / cancellation emits errors; ignore benign ones.
            }
        }

        do {
            try engine.start()
        } catch {
            NSLog("VoiceInput: audio engine failed: \(error)")
            overlay.updateTranscript("无法启动麦克风。")
        }
    }

    private func processRMS(_ buffer: AVAudioPCMBuffer) {
        let rms = Self.rms(buffer: buffer)
        DispatchQueue.main.async { [weak self] in
            self?.applySmoothedLevels(rms)
        }
    }

    private func applySmoothedLevels(_ rms: Float) {
        let normalized = min(1.0, max(0.0, rms * 12.0))
        if normalized > lastRMS {
            lastRMS += (normalized - lastRMS) * attack
        } else {
            lastRMS += (normalized - lastRMS) * release
        }
        var levels = [Float](repeating: 0, count: 7)
        for i in 0 ..< 7 {
            let jitter = 1.0 + Float.random(in: -0.04 ... 0.04)
            levels[i] = min(1.0, lastRMS * weights[i] * jitter)
        }
        overlay.updateWaveformLevels(levels)
    }

    private static func rms(buffer: AVAudioPCMBuffer) -> Float {
        guard let ch = buffer.floatChannelData else { return 0 }
        let n = Int(buffer.frameLength)
        if n == 0 { return 0 }
        var sum: Float = 0
        let p = ch[0]
        for i in 0 ..< n {
            let s = p[i]
            sum += s * s
        }
        return sqrt(sum / Float(n))
    }

    private static func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { c in
            AVAudioApplication.requestRecordPermission { granted in
                c.resume(returning: granted)
            }
        }
    }

    private static func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { c in
            SFSpeechRecognizer.requestAuthorization { status in
                c.resume(returning: status == .authorized)
            }
        }
    }

    private func finalize(text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            await MainActor.run { self.overlay.hide() }
            return
        }

        let enabled = settings.llmRefinementEnabled && settings.isLLMConfigured
        if enabled {
            await MainActor.run {
                self.overlay.setState(.refining)
            }
            do {
                let refined = try await LLMRefinementService.refine(trimmed, settings: settings)
                await MainActor.run {
                    PasteInjector.inject(refined)
                    self.overlay.hide()
                }
            } catch {
                await MainActor.run {
                    PasteInjector.inject(trimmed)
                    self.overlay.hide()
                }
            }
        } else {
            await MainActor.run {
                PasteInjector.inject(trimmed)
                self.overlay.hide()
            }
        }
    }
}
