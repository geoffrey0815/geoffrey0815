import Foundation

/// Splits a long transcript into pieces that fit the on-device model's context,
/// for map-reduce summarization. Splits on segment boundaries; a single segment longer
/// than the budget is split at its last sentence end, else its last space, and is only
/// hard-split when it has neither (e.g. unpunctuated, unspaced text).
public enum TranscriptChunker {
    /// - Parameter maxCharacters: budget per chunk. The system model has a 4,096-token
    ///   window shared by instructions, input and output; ~1,500 Korean characters
    ///   leaves room for the rest. Tune with Spike B.
    public static func chunks(of segments: [MeetingResult.Segment], maxCharacters: Int = 1_500) -> [String] {
        precondition(maxCharacters > 0)
        var chunks: [String] = []
        var current = ""
        for segment in segments {
            let line = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            if !current.isEmpty, current.count + 1 + line.count > maxCharacters {
                chunks.append(current)
                current = ""
            }
            var remainder = Substring(line)
            while remainder.count > maxCharacters {
                if !current.isEmpty {
                    chunks.append(current)
                    current = ""
                }
                let cut = splitPoint(in: remainder.prefix(maxCharacters))
                chunks.append(String(remainder[..<cut]).trimmingCharacters(in: .whitespaces))
                remainder = remainder[cut...].drop(while: \.isWhitespace)
            }
            current += current.isEmpty ? String(remainder) : "\n" + String(remainder)
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }

    /// End index for a piece of `window`: after the last sentence terminator, else at the
    /// last space, else the whole window. Cuts in the first half are ignored so pieces
    /// don't become tiny.
    static func splitPoint(in window: Substring) -> Substring.Index {
        let minimum = window.index(window.startIndex, offsetBy: window.count / 2)
        let terminators: Set<Character> = [".", "?", "!", "。", "？", "！"]
        if let end = window[minimum...].lastIndex(where: { terminators.contains($0) }) {
            return window.index(after: end)
        }
        if let space = window[minimum...].lastIndex(where: \.isWhitespace) {
            return space
        }
        return window.endIndex
    }
}
