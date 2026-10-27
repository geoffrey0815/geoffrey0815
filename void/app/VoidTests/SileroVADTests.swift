import AVFoundation
import XCTest
@testable import VoidMain

/// The bundled Silero model must load and tell speech from silence and steady noise,
/// using the same 48 kHz / 4096-frame buffers the microphone tap delivers.
final class SileroVADTests: XCTestCase {
    private let micFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 1, interleaved: false)!

    func testBundledModelLoads() {
        XCTAssertNotNil(SileroVAD.bundled(), "silero_vad.onnx must be in the app bundle and load in ONNX Runtime")
    }

    func testSilenceIsNotSpeech() throws {
        let vad = try XCTUnwrap(SileroVAD.bundled())
        let results = (0..<40).map { _ in vad.isSpeech(makeBuffer { _ in 0 }) }
        XCTAssertFalse(results.contains(true))
    }

    func testSteadyNoiseIsMostlyNotSpeech() throws {
        let vad = try XCTUnwrap(SileroVAD.bundled())
        var generator = SystemRandomNumberGenerator()
        let results = (0..<60).map { _ in vad.isSpeech(makeBuffer { _ in Float.random(in: -0.05...0.05, using: &generator) }) }
        let ratio = Double(results.filter { $0 }.count) / Double(results.count)
        XCTAssertLessThan(ratio, 0.2, "fan-like noise must not keep a recording alive")
    }

    func testSynthesizedSpeechIsSpeech() async throws {
        let vad = try XCTUnwrap(SileroVAD.bundled())
        let buffers = try await synthesize("Good morning everyone. Let's review the fourth quarter roadmap. The first item is the release date, which we will fix today.")
        XCTAssertFalse(buffers.isEmpty, "speech synthesis produced no audio")
        let results = buffers.map(vad.isSpeech)
        let ratio = Double(results.filter { $0 }.count) / Double(results.count)
        XCTAssertGreaterThan(ratio, 0.4, "speech ratio \(ratio)")
    }

    private func makeBuffer(_ sample: (Int) -> Float) -> AVAudioPCMBuffer {
        let buffer = AVAudioPCMBuffer(pcmFormat: micFormat, frameCapacity: 4096)!
        buffer.frameLength = 4096
        let channel = buffer.floatChannelData![0]
        for i in 0..<4096 { channel[i] = sample(i) }
        return buffer
    }

    /// Renders text with the system voice into buffers re-chunked like the microphone tap.
    private func synthesize(_ text: String) async throws -> [AVAudioPCMBuffer] {
        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        // The callback may be @Sendable, so state lives in a box rather than captured vars.
        final class Collector: @unchecked Sendable {
            var buffers: [AVAudioPCMBuffer] = []
            var finished = false
        }
        let collector = Collector()
        // Bounded wait: a simulator without voices never calls back, which would hang the run.
        let done = expectation(description: "speech synthesized")
        synthesizer.write(utterance) { buffer in
            guard !collector.finished else { return }
            guard let pcm = buffer as? AVAudioPCMBuffer, pcm.frameLength > 0 else {
                collector.finished = true
                done.fulfill()
                return
            }
            if let copy = pcm.copy() { collector.buffers.append(copy) }
        }
        await fulfillment(of: [done], timeout: 30)
        collector.finished = true
        let rendered = collector.buffers
        if rendered.isEmpty {
            throw XCTSkip("this simulator has no speech voice to synthesize test audio")
        }
        // Convert to the microphone format and cut into 4096-frame buffers.
        var samples: [Float] = []
        for buffer in rendered {
            guard let converter = AVAudioConverter(from: buffer.format, to: micFormat),
                  let converted = buffer.converted(with: converter, to: micFormat),
                  let data = converted.floatChannelData?[0] else { continue }
            samples.append(contentsOf: UnsafeBufferPointer(start: data, count: Int(converted.frameLength)))
        }
        return stride(from: 0, to: samples.count - 4096, by: 4096).map { start in
            makeBuffer { samples[start + $0] }
        }
    }
}
