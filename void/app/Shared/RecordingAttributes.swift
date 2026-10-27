import ActivityKit
import Foundation

/// Live Activity shown on the Lock Screen and Dynamic Island while recording.
struct RecordingAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startedAt: Date
        /// Set while the silence warning is up: when the recording will stop on its own.
        var autoStopAt: Date?
    }
}
