import Foundation

/// Decides when a recording should auto-stop after continuous silence.
///
/// Pure state machine: feed it one VAD decision per audio frame together with the
/// frame's timestamp (seconds since recording start). It never touches audio itself,
/// so the same logic drives the app, the spikes, and the tests.
public struct SilenceMonitor: Sendable {
    public struct Configuration: Sendable, Equatable {
        /// Continuous silence that ends the recording (the "m minutes" setting).
        public var timeout: TimeInterval
        /// How long before the timeout the user is warned, so a quiet meeting can be kept alive.
        public var warningLead: TimeInterval
        /// Speech shorter than this does not reset the silence timer (coughs, door slams).
        public var minSpeechDuration: TimeInterval

        public init(timeout: TimeInterval = 180, warningLead: TimeInterval = 30, minSpeechDuration: TimeInterval = 0.5) {
            precondition(timeout > 0, "timeout must be positive")
            self.timeout = timeout
            self.warningLead = min(max(warningLead, 0), timeout)
            self.minSpeechDuration = max(minSpeechDuration, 0)
        }
    }

    public enum Event: Sendable, Equatable {
        /// Silence will end the recording in `remaining` seconds.
        case warning(remaining: TimeInterval)
        /// Speech came back after a warning was raised.
        case warningCancelled
        /// Silence reached the timeout; stop the recording.
        case timeout
    }

    public let configuration: Configuration
    private var silenceStart: TimeInterval?
    private var speechStart: TimeInterval?
    private var warned = false
    private var finished = false

    public init(configuration: Configuration = .init()) {
        self.configuration = configuration
        self.silenceStart = 0
    }

    /// Current length of the silence run at `time`, or 0 while someone is talking.
    public func silenceDuration(at time: TimeInterval) -> TimeInterval {
        guard let silenceStart else { return 0 }
        return max(time - silenceStart, 0)
    }

    /// Feeds one VAD decision. Returns an event when the state changes.
    public mutating func process(isSpeech: Bool, at time: TimeInterval) -> Event? {
        guard !finished else { return nil }

        if isSpeech {
            if speechStart == nil { speechStart = time }
            // Only a sustained burst of speech counts as the meeting resuming.
            guard let speechStart, time - speechStart >= configuration.minSpeechDuration else {
                return evaluateSilence(at: time)
            }
            silenceStart = nil
            if warned {
                warned = false
                return .warningCancelled
            }
            return nil
        }

        speechStart = nil
        if silenceStart == nil { silenceStart = time }
        return evaluateSilence(at: time)
    }

    /// Restarts the silence timer, e.g. when the user taps "keep recording" on the warning.
    public mutating func extend(at time: TimeInterval) -> Event? {
        guard !finished, silenceStart != nil else { return nil }
        silenceStart = time
        if warned {
            warned = false
            return .warningCancelled
        }
        return nil
    }

    private mutating func evaluateSilence(at time: TimeInterval) -> Event? {
        let silence = silenceDuration(at: time)
        if silence >= configuration.timeout {
            finished = true
            return .timeout
        }
        let warnAt = configuration.timeout - configuration.warningLead
        if !warned, configuration.warningLead > 0, silence >= warnAt {
            warned = true
            return .warning(remaining: configuration.timeout - silence)
        }
        return nil
    }
}
