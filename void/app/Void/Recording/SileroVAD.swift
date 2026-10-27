import AVFoundation
import OnnxRuntimeBindings

/// Decides whether a microphone buffer contains speech. Called on the audio tap thread.
protocol VoiceActivityDetector: AnyObject {
    func isSpeech(_ buffer: AVAudioPCMBuffer) -> Bool
}

/// Silero VAD v4 (bundled `silero_vad.onnx`, MIT) running on ONNX Runtime, fully on-device.
///
/// Unlike an energy threshold it ignores fans, keyboards and other non-speech noise, which
/// matters because a false "speech" keeps a finished meeting recording forever (Spike D).
/// The model takes 512-sample windows of 16 kHz mono audio and carries LSTM state (h, c).
final class SileroVAD: VoiceActivityDetector {
    static let sampleRate = 16_000.0
    static let windowSize = 512
    private static let stateCount = 2 * 1 * 64

    /// Hysteresis: enter speech above `onThreshold`, leave below `offThreshold`.
    var onThreshold: Float = 0.5
    var offThreshold: Float = 0.35

    private let session: ORTSession
    private let targetFormat: AVAudioFormat
    private var converter: AVAudioConverter?
    private var h = [Float](repeating: 0, count: stateCount)
    private var c = [Float](repeating: 0, count: stateCount)
    private var pending: [Float] = []
    private var speaking = false

    init(modelURL: URL) throws {
        let env = try ORTEnv(loggingLevel: .warning)
        let options = try ORTSessionOptions()
        try options.setIntraOpNumThreads(1)
        session = try ORTSession(env: env, modelPath: modelURL.path, sessionOptions: options)
        targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Self.sampleRate, channels: 1, interleaved: false)!
    }

    /// Bundled model, or nil if it is missing or ONNX Runtime fails to load it.
    static func bundled() -> SileroVAD? {
        guard let url = Bundle.main.url(forResource: "silero_vad", withExtension: "onnx") else { return nil }
        return try? SileroVAD(modelURL: url)
    }

    func isSpeech(_ buffer: AVAudioPCMBuffer) -> Bool {
        pending.append(contentsOf: resample(buffer))
        var maxProbability: Float = 0
        var consumed = 0
        while pending.count - consumed >= Self.windowSize {
            let window = Array(pending[consumed ..< consumed + Self.windowSize])
            consumed += Self.windowSize
            if let p = try? probability(of: window) {
                maxProbability = max(maxProbability, p)
            }
        }
        pending.removeFirst(consumed)
        speaking = speaking ? maxProbability >= offThreshold : maxProbability >= onThreshold
        return speaking
    }

    private func probability(of window: [Float]) throws -> Float {
        let outputs = try session.run(
            withInputs: [
                "x": try tensor(window, shape: [1, NSNumber(value: Self.windowSize)]),
                "h": try tensor(h, shape: [2, 1, 64]),
                "c": try tensor(c, shape: [2, 1, 64]),
            ],
            outputNames: ["prob", "new_h", "new_c"],
            runOptions: nil
        )
        guard let prob = outputs["prob"], let newH = outputs["new_h"], let newC = outputs["new_c"] else {
            throw VADError.missingOutput
        }
        h = try floats(newH)
        c = try floats(newC)
        return try floats(prob).first ?? 0
    }

    private func tensor(_ values: [Float], shape: [NSNumber]) throws -> ORTValue {
        let data = values.withUnsafeBufferPointer { NSMutableData(bytes: $0.baseAddress, length: $0.count * MemoryLayout<Float>.stride) }
        return try ORTValue(tensorData: data, elementType: .float, shape: shape)
    }

    private func floats(_ value: ORTValue) throws -> [Float] {
        let data = try value.tensorData() as Data
        return data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }

    private func resample(_ buffer: AVAudioPCMBuffer) -> [Float] {
        if converter?.inputFormat != buffer.format {
            converter = AVAudioConverter(from: buffer.format, to: targetFormat)
        }
        guard let converter,
              let output = buffer.converted(with: converter, to: targetFormat),
              let samples = output.floatChannelData?[0] else { return [] }
        return Array(UnsafeBufferPointer(start: samples, count: Int(output.frameLength)))
    }

    private enum VADError: Error {
        case missingOutput
    }
}
