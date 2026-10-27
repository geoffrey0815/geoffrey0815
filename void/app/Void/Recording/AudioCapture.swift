import AVFoundation

/// Owns the audio engine. Writes the microphone to an AAC file and reports one VAD
/// decision per buffer, plus interruption changes. The tap runs on the audio render
/// thread; consumers read `events` on their own executor.
final class AudioCapture: @unchecked Sendable {
    struct Frame: Sendable {
        /// Seconds of audio recorded so far, derived from samples written (not wall clock),
        /// so time spent in an interruption never counts as silence.
        let time: TimeInterval
        let isSpeech: Bool
        let level: Float
    }

    enum Event: Sendable {
        case frame(Frame)
        /// A call, Siri or another app took the microphone.
        case interrupted
        case resumed
        /// The engine could not be restarted after an interruption or route change.
        case failed(String)
    }

    private let engine = AVAudioEngine()
    private var file: AVAudioFile?
    private var vad: any VoiceActivityDetector = EnergyVAD()
    private var framesWritten: AVAudioFramePosition = 0
    private var writeFailed = false
    private var continuation: AsyncStream<Event>.Continuation?
    private var observers: [NSObjectProtocol] = []

    func start(writingTo url: URL) throws -> AsyncStream<Event> {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default)
        try session.setActive(true)

        let format = engine.inputNode.outputFormat(forBus: 0)
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
        writeFailed = false
        vad = SileroVAD.bundled().map { $0 as any VoiceActivityDetector } ?? EnergyVAD()

        let (stream, continuation) = AsyncStream.makeStream(of: Event.self, bufferingPolicy: .bufferingNewest(256))
        self.continuation = continuation

        try startEngine()
        observeSession()
        return stream
    }

    func stop() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        file = nil // closing the file finalizes the AAC container
        continuation?.finish()
        continuation = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func startEngine() throws {
        guard let file else { return }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        // The file's format is fixed when it is created; a route change to a mic with a
        // different rate or channel count would corrupt it. TODO: convert with AVAudioConverter.
        guard format.sampleRate == file.processingFormat.sampleRate,
              format.channelCount == file.processingFormat.channelCount else {
            throw CaptureError.formatChanged
        }
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            self?.handle(buffer, sampleRate: format.sampleRate)
        }
        engine.prepare()
        try engine.start()
    }

    private func observeSession() {
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: nil) { [weak self] note in
                self?.handleInterruption(note)
            },
            // Route changes (headset plugged in, Bluetooth mic) stop the engine and reset its graph.
            center.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil) { [weak self] _ in
                self?.restart()
            },
            center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: nil) { [weak self] _ in
                self?.continuation?.yield(.failed("오디오 시스템이 재설정되어 녹음이 중단되었습니다."))
            },
        ]
    }

    private func handleInterruption(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        switch type {
        case .began:
            continuation?.yield(.interrupted)
        case .ended:
            // A meeting recorder should come back after a call even without .shouldResume;
            // if the system refuses, the controller ends the meeting with what it has.
            restart()
        @unknown default:
            break
        }
    }

    private func restart() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            try startEngine()
            continuation?.yield(.resumed)
        } catch CaptureError.formatChanged {
            continuation?.yield(.failed("마이크가 바뀌어 녹음을 이어갈 수 없습니다."))
        } catch {
            continuation?.yield(.failed("녹음을 다시 시작하지 못했습니다: \(error.localizedDescription)"))
        }
    }

    private func handle(_ buffer: AVAudioPCMBuffer, sampleRate: Double) {
        do {
            try file?.write(from: buffer)
        } catch {
            if !writeFailed {
                writeFailed = true
                continuation?.yield(.failed("녹음 파일을 쓰지 못했습니다: \(error.localizedDescription)"))
            }
            return
        }
        let time = Double(framesWritten) / sampleRate
        framesWritten += AVAudioFramePosition(buffer.frameLength)
        continuation?.yield(.frame(Frame(time: time, isSpeech: vad.isSpeech(buffer), level: EnergyVAD.rms(buffer))))
    }

    private enum CaptureError: Error {
        case formatChanged
    }
}
