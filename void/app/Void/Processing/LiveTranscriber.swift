import AVFoundation
import CoreMedia
import Speech
import VoidCore

/// Transcribes while recording, so the transcript is ready the moment recording stops.
///
/// `append` is called from the audio tap thread. Buffers are copied into an unbounded
/// stream right away, so nothing is lost while the analyzer is still loading its model;
/// a background task converts them to the analyzer's format and feeds it.
final class LiveTranscriber: @unchecked Sendable {
    private let raw: AsyncStream<AVAudioPCMBuffer>
    private let rawContinuation: AsyncStream<AVAudioPCMBuffer>.Continuation
    private var task: Task<[MeetingResult.Segment], Error>?

    init(locale: Locale) {
        (raw, rawContinuation) = AsyncStream.makeStream(of: AVAudioPCMBuffer.self, bufferingPolicy: .unbounded)
        let raw = raw
        task = Task.detached(priority: .utility) {
            try await Self.run(locale: locale, buffers: raw)
        }
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        // The engine reuses tap buffers after the callback returns; keep our own copy.
        if let copy = buffer.copy() { rawContinuation.yield(copy) }
    }

    /// Ends the input and waits for the remaining audio to be transcribed.
    func finish() async throws -> [MeetingResult.Segment] {
        rawContinuation.finish()
        return try await task?.value ?? []
    }

    func cancel() {
        rawContinuation.finish()
        task?.cancel()
    }

    private static func run(locale: Locale, buffers: AsyncStream<AVAudioPCMBuffer>) async throws -> [MeetingResult.Segment] {
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
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw TranscriberError.noAudioFormat
        }

        let (input, inputContinuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
        async let segments = transcriber.results.reduce(into: [MeetingResult.Segment]()) { list, result in
            let text = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            list.append(.init(start: result.range.start.seconds, end: result.range.end.seconds, text: text))
        }
        try await analyzer.start(inputSequence: input)

        var converter: AVAudioConverter?
        for await buffer in buffers {
            if converter?.inputFormat != buffer.format {
                converter = AVAudioConverter(from: buffer.format, to: format)
            }
            if let converter, let converted = buffer.converted(with: converter, to: format) {
                inputContinuation.yield(AnalyzerInput(buffer: converted))
            }
        }
        inputContinuation.finish()
        try await analyzer.finalizeAndFinishThroughEndOfInput()
        return try await segments
    }
}

extension AVAudioPCMBuffer {
    func copy() -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength) else { return nil }
        copy.frameLength = frameLength
        let source = UnsafeMutableAudioBufferListPointer(mutableAudioBufferList)
        let target = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
        for (from, to) in zip(source, target) {
            guard let src = from.mData, let dst = to.mData else { continue }
            memcpy(dst, src, Int(min(from.mDataByteSize, to.mDataByteSize)))
        }
        return copy
    }

    func converted(with converter: AVAudioConverter, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        if self.format == format { return self }
        let capacity = AVAudioFrameCount(Double(frameLength) * format.sampleRate / self.format.sampleRate) + 1
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        var supplied = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if supplied {
                status.pointee = .noDataNow
                return nil
            }
            supplied = true
            status.pointee = .haveData
            return self
        }
        return error == nil ? output : nil
    }
}
