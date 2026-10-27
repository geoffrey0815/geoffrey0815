import AVFoundation

/// Fallback detector used only if the bundled Silero model cannot be loaded:
/// level above an adaptive noise floor. Fans and keyboards can fool it.
final class EnergyVAD: VoiceActivityDetector {
    /// dB above the noise floor that counts as speech.
    var margin: Float = 12
    private(set) var noiseFloor: Float = -50

    func isSpeech(_ buffer: AVAudioPCMBuffer) -> Bool {
        let db = 20 * log10(max(Self.rms(buffer), 1e-7))
        if db < noiseFloor {
            noiseFloor = db // drop fast to quiet rooms
        } else {
            noiseFloor += (db - noiseFloor) * 0.0005 // rise slowly so speech does not become "floor"
        }
        return db > noiseFloor + margin
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
