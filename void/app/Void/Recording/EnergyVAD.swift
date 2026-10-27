import AVFoundation

/// Fallback detector used only if the bundled Silero model cannot be loaded:
/// level above an adaptive noise floor. Noise louder than the margin (fans, keyboards)
/// reads as speech and keeps a recording alive; that is why Silero is the default.
final class EnergyVAD: VoiceActivityDetector {
    /// dB above the noise floor that counts as speech.
    var margin: Float = 12
    private(set) var noiseFloor: Float = -50

    func isSpeech(_ buffer: AVAudioPCMBuffer) -> Bool {
        let db = 20 * log10(max(Self.rms(buffer), 1e-7))
        let speech = db > noiseFloor + margin
        if db < noiseFloor {
            noiseFloor = db // drop fast to quiet rooms
        } else if !speech {
            // Track the room only on non-speech frames; adapting during speech would let a
            // long monologue become the "floor" and read as silence.
            noiseFloor += (db - noiseFloor) * 0.01
        }
        return speech
    }

    static func rms(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<Int(buffer.frameLength) {
            sum += channel[i] * channel[i]
        }
        return (sum / Float(buffer.frameLength)).squareRoot()
    }
}
