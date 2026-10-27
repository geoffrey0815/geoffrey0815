import AVFoundation
import CoreMedia
import Foundation
import Speech
import VoidCore

/// On-device speech-to-text. The engine choice (SpeechAnalyzer vs WhisperKit) is ADR-0002;
/// this protocol keeps the pipeline independent of it.
protocol Transcriber: Sendable {
    func transcribe(fileAt url: URL, locale: Locale) async throws -> [MeetingResult.Segment]
}

/// Apple SpeechAnalyzer (iOS 26). The language model is an OS asset downloaded once
/// per language; after that, transcription runs fully offline.
struct SpeechAnalyzerTranscriber: Transcriber {
    func transcribe(fileAt url: URL, locale: Locale) async throws -> [MeetingResult.Segment] {
        guard let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            throw TranscriberError.unsupportedLocale(locale.identifier)
        }
        let transcriber = SpeechTranscriber(
            locale: supported,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: [.audioTimeRange]
        )
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        await analyzer.useGlossary(AppSettings.glossary)
        let file = try AVAudioFile(forReading: url)

        async let segments = transcriber.results.reduce(into: [MeetingResult.Segment]()) { list, result in
            let text = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            list.append(.init(start: result.range.start.seconds, end: result.range.end.seconds, text: text))
        }
        if let lastSample = try await analyzer.analyzeSequence(from: file) {
            try await analyzer.finalizeAndFinish(through: lastSample)
        } else {
            await analyzer.cancelAndFinishNow()
        }
        return try await segments
    }
}

extension SpeechAnalyzer {
    /// Biases recognition toward the user's glossary. Best effort: a failure here must not
    /// stop the transcription itself.
    func useGlossary(_ terms: [String]) async {
        guard !terms.isEmpty else { return }
        let context = AnalysisContext()
        context.contextualStrings[.general] = terms
        try? await setContext(context)
    }
}

enum TranscriberError: LocalizedError {
    case unsupportedLocale(String)
    case noAudioFormat

    var errorDescription: String? {
        switch self {
        case .unsupportedLocale(let id): "이 기기는 \(id) 받아쓰기를 지원하지 않습니다."
        case .noAudioFormat: "받아쓰기용 오디오 형식을 정하지 못했습니다."
        }
    }
}
