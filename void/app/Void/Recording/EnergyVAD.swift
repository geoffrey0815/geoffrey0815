import Foundation

/// Placeholder voice-activity detector: level above an adaptive noise floor.
///
/// Good enough to wire up the silence auto-stop end to end. Spike D recommends swapping
/// in Silero VAD (Core ML) because fans and keyboards fool an energy threshold.
struct EnergyVAD {
    /// dB above the noise floor that counts as speech.
    var margin: Float = 12
    private(set) var noiseFloor: Float = -50

    mutating func isSpeech(rms: Float) -> Bool {
        let db = 20 * log10(max(rms, 1e-7))
        if db < noiseFloor {
            noiseFloor = db // drop fast to quiet rooms
        } else {
            noiseFloor += (db - noiseFloor) * 0.0005 // rise slowly so speech does not become "floor"
        }
        return db > noiseFloor + margin
    }
}
