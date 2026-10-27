import Foundation

/// Splits a long transcript into pieces that fit the on-device model's context,
/// for map-reduce summarization. Splits on segment boundaries, never mid-sentence.
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
            // A single segment longer than the budget is hard-split.
            var remainder = Substring(line)
            while remainder.count > maxCharacters {
                if !current.isEmpty {
                    chunks.append(current)
                    current = ""
                }
                chunks.append(String(remainder.prefix(maxCharacters)))
                remainder = remainder.dropFirst(maxCharacters)
            }
            current += current.isEmpty ? String(remainder) : "\n" + String(remainder)
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }
}
