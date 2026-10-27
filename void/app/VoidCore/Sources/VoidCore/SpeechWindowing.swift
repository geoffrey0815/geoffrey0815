import Foundation

/// Groups VAD speech spans into windows for the STT engine.
///
/// Decoding each VAD span on its own starves Whisper-style models of context: in Spike A
/// (52-min talk, median span 2.8 s) it produced fragments like "Moses." and "peach".
/// Merging neighbours into ≤25 s windows gave ~8% more words, far more coherent text,
/// and halved decode time because there are fewer decoder passes.
public enum SpeechWindowing {
    public struct Span: Sendable, Equatable {
        public var start: TimeInterval
        public var end: TimeInterval

        public init(start: TimeInterval, end: TimeInterval) {
            self.start = start
            self.end = end
        }

        public var duration: TimeInterval { end - start }
    }

    /// - Parameters:
    ///   - spans: speech spans in time order.
    ///   - maxWindow: target window length; neighbours are merged while the window stays within it.
    ///   - maxGap: silence longer than this always starts a new window (a topic or speaker change is likely).
    ///   - hardLimit: the engine's input limit (Whisper: 30 s). Longer spans are split, never truncated.
    public static func windows(
        for spans: [Span],
        maxWindow: TimeInterval = 25,
        maxGap: TimeInterval = 3,
        hardLimit: TimeInterval = 29.5
    ) -> [Span] {
        precondition(maxWindow > 0 && hardLimit >= maxWindow)
        var windows: [Span] = []
        for span in spans where span.end > span.start {
            if var last = windows.last, span.end - last.start <= maxWindow, span.start - last.end <= maxGap {
                last.end = span.end
                windows[windows.count - 1] = last
                continue
            }
            // Split an over-long span into equal pieces under the hard limit.
            let pieces = Int((span.duration / hardLimit).rounded(.up))
            let length = span.duration / Double(pieces)
            let boundaries = (0...pieces).map { $0 == pieces ? span.end : span.start + Double($0) * length }
            for (start, end) in zip(boundaries, boundaries.dropFirst()) {
                windows.append(Span(start: start, end: end))
            }
        }
        return windows
    }
}
