import AVFoundation

/// Owns the audio engine. Writes the microphone to an AAC file and reports one VAD
/// decision per buffer. Everything here runs on the audio render thread; consumers
/// read `frames` on their own executor.
final class AudioCapture: @unchecked Sendable {
    struct Frame: Sendable {
        /// Seconds since the recording started, derived from samples written (not wall clock).
        let time: TimeInterval
        let isSpeech: Bool
        let level: Float
    }

    private let engine = AVAudioEngine()
    private var file: AVAudioFile?
    private var vad = EnergyVAD()
    private var framesWritten: AVAudioFramePosition = 0
    private var continuation: AsyncStream<Frame>.Continuation?

    func start(writingTo url: URL) throws -> AsyncStream<Frame> {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default)
        try session.setActive(true)

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        file = try AVAudioFile(
            forWriting: url,
            settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: format.sampleRate,
                AVNumberOfChannelsKey: format.channelCount,
                AVEncoderBitRateKey: 64_000,
            ],
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        framesWritten = 0
        vad = EnergyVAD()

        let (stream, continuation) = AsyncStream.makeStream(of: Frame.self, bufferingPolicy: .bufferingNewest(256))
        self.continuation = continuation

        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            self?.handle(buffer, sampleRate: format.sampleRate)
        }
        engine.prepare()
        try engine.start()
        return stream
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        file = nil // closing the file finalizes the AAC container
        continuation?.finish()
        continuation = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func handle(_ buffer: AVAudioPCMBuffer, sampleRate: Double) {
        do {
            try file?.write(from: buffer)
        } catch {
            // TODO: surface write failures (disk full) to the controller.
        }
        let time = Double(framesWritten) / sampleRate
        framesWritten += AVAudioFramePosition(buffer.frameLength)
        let level = Self.rms(buffer)
        continuation?.yield(Frame(time: time, isSpeech: vad.isSpeech(rms: level), level: level))
    }

    private static func rms(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<Int(buffer.frameLength) {
            sum += channel[i] * channel[i]
        }
        return (sum / Float(buffer.frameLength)).squareRoot()
    }
}
