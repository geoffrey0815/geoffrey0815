import Foundation

/// Picks the transcript chunks most relevant to a question, so a question about a long
/// meeting fits the on-device model's context. Plain term overlap: no embeddings, no network.
public enum TranscriptRetriever {
    /// - Returns: up to `limit` chunks, best first; chunks sharing no term with the question
    ///   are dropped, and if none match, the first chunks are returned as context.
    public static func relevantChunks(for question: String, in chunks: [String], limit: Int = 2) -> [String] {
        precondition(limit > 0)
        let queryTerms = terms(in: question)
        guard !queryTerms.isEmpty else { return Array(chunks.prefix(limit)) }

        let scored = chunks.enumerated().compactMap { index, chunk -> (index: Int, score: Double)? in
            let chunkTerms = terms(in: chunk)
            let hits = queryTerms.filter { term in chunkTerms.contains { $0.hasPrefix(term) || term.hasPrefix($0) } }
            guard !hits.isEmpty else { return nil }
            // Favour chunks matching more distinct terms, then longer (more specific) ones.
            let score = Double(hits.count) + Double(hits.map(\.count).reduce(0, +)) * 0.01
            return (index, score)
        }
        guard !scored.isEmpty else { return Array(chunks.prefix(limit)) }
        return scored
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.index < $1.index }
            .prefix(limit)
            .map { chunks[$0.index] }
    }

    /// Lowercased words of two or more characters, with Korean particles trimmed so
    /// "출시는" matches "출시".
    static func terms(in text: String) -> Set<String> {
        let particles = ["은", "는", "이", "가", "을", "를", "에", "의", "도", "로", "으로", "에서", "와", "과", "랑", "까지", "부터", "요"]
        var result = Set<String>()
        for raw in text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }) {
            var word = String(raw)
            for particle in particles.sorted(by: { $0.count > $1.count }) where word.count > particle.count + 1 && word.hasSuffix(particle) {
                word.removeLast(particle.count)
                break
            }
            if word.count >= 2 { result.insert(word) }
        }
        return result
    }
}
