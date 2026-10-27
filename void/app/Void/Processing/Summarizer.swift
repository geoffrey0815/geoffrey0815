import Foundation
import FoundationModels
import VoidCore

@Generable
struct ChunkNotes {
    @Guide(description: "Key points discussed in this part, 3 to 6 short sentences")
    var points: [String]
    @Guide(description: "Decisions that were settled in this part. Empty if none")
    var decisions: [String]
    @Guide(description: "Who agreed to do what. Empty if none")
    var actionItems: [GeneratedActionItem]
}

@Generable
struct GeneratedActionItem {
    @Guide(description: "The task, one sentence starting with a verb")
    var task: String
    @Guide(description: "Owner's name, or an empty string if nobody was named")
    var owner: String
}

@Generable
struct GeneratedSummary {
    @Guide(description: "Short title for the meeting, at most 30 characters")
    var title: String
    @Guide(description: "Overall summary in 3 to 5 sentences")
    var summary: String
    var decisions: [String]
    var actionItems: [GeneratedActionItem]
}

/// Map-reduce summarization with the on-device system model (4,096-token context).
/// Same approach as spikes/B-summary-bench; chunk size is tuned there.
struct Summarizer {
    var maxCharactersPerChunk = 1_500

    func summarize(_ segments: [MeetingResult.Segment], outputLanguage: String) async throws -> GeneratedSummary {
        guard case .available = SystemLanguageModel.default.availability else {
            throw SummarizerError.modelUnavailable
        }
        let languageName = Locale.current.localizedString(forLanguageCode: outputLanguage) ?? outputLanguage
        let instructions = """
        You write meeting notes. Use only what is in the transcript; never invent facts.
        The transcript comes from speech recognition, so silently fix words that are clearly misheard.
        If the recording is a talk or lecture rather than a meeting, leave decisions empty.
        Write everything in \(languageName).
        """

        let chunks = TranscriptChunker.chunks(of: segments, maxCharacters: maxCharactersPerChunk)
        guard !chunks.isEmpty else { throw SummarizerError.emptyTranscript }

        // Map: a fresh session per chunk so earlier chunks don't consume the context window.
        var notes: [ChunkNotes] = []
        for (index, chunk) in chunks.enumerated() {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(
                to: "Part \(index + 1) of \(chunks.count) of the transcript:\n\n\(chunk)",
                generating: ChunkNotes.self
            )
            notes.append(response.content)
        }

        // Reduce hierarchically: merge groups of notes that fit the budget into one set of
        // notes, repeating until everything fits in a single final request.
        while notes.count > 1, render(notes).count > maxCharactersPerChunk {
            var merged: [ChunkNotes] = []
            for group in batches(of: notes) {
                guard group.count > 1 else {
                    merged.append(contentsOf: group)
                    continue
                }
                let session = LanguageModelSession(instructions: instructions)
                merged.append(try await session.respond(
                    to: "Notes from consecutive parts of one meeting. Merge them, dropping duplicates.\n\n\(render(group))",
                    generating: ChunkNotes.self
                ).content)
            }
            notes = merged
        }

        let session = LanguageModelSession(instructions: instructions)
        return try await session.respond(
            to: "Notes from consecutive parts of one meeting. Merge duplicates and write the final notes.\n\n\(render(notes))",
            generating: GeneratedSummary.self
        ).content
    }

    private func render(_ notes: [ChunkNotes]) -> String {
        notes.map { note in
            """
            Points: \(note.points.joined(separator: " / "))
            Decisions: \(note.decisions.joined(separator: " / "))
            Action items: \(note.actionItems.map { "\($0.task) (\($0.owner))" }.joined(separator: " / "))
            """
        }.joined(separator: "\n\n")
    }

    /// Consecutive groups whose rendered notes stay within the chunk budget. Groups always
    /// take at least two notes, so every round at least halves the count and terminates.
    private func batches(of notes: [ChunkNotes]) -> [[ChunkNotes]] {
        var groups: [[ChunkNotes]] = []
        var current: [ChunkNotes] = []
        for note in notes {
            if current.count >= 2, render(current + [note]).count > maxCharactersPerChunk {
                groups.append(current)
                current = []
            }
            current.append(note)
        }
        if !current.isEmpty { groups.append(current) }
        return groups
    }
}

enum SummarizerError: LocalizedError {
    case modelUnavailable, emptyTranscript

    var errorDescription: String? {
        switch self {
        case .modelUnavailable: "Apple Intelligence를 켜야 요약할 수 있습니다."
        case .emptyTranscript: "받아쓴 내용이 없습니다."
        }
    }
}
