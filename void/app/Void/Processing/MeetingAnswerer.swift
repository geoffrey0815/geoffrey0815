import Foundation
import FoundationModels
import VoidCore

/// Answers a question about one meeting (PRD F9). On-device only, like the summary.
protocol MeetingAnswerer {
    func answer(_ question: String, about meeting: MeetingNotes) async throws -> String
}

/// The parts of a meeting the answerer may use; a value copy so no model object crosses tasks.
struct MeetingNotes: Sendable {
    var title: String
    var summary: String
    var decisions: [String]
    var actionItems: [MeetingResult.ActionItem]
    var transcript: [MeetingResult.Segment]

    @MainActor
    init(_ meeting: Meeting) {
        title = meeting.displayTitle
        summary = meeting.summary
        decisions = meeting.decisions
        actionItems = meeting.actionItems
        transcript = meeting.transcript
    }
}

/// The system language model, given the notes plus the transcript excerpts most relevant to
/// the question (the whole transcript would not fit its 4,096-token context).
struct OnDeviceAnswerer: MeetingAnswerer {
    func answer(_ question: String, about meeting: MeetingNotes) async throws -> String {
        guard case .available = SystemLanguageModel.default.availability else {
            throw SummarizerError.modelUnavailable
        }
        let chunks = TranscriptChunker.chunks(of: meeting.transcript, maxCharacters: 1_200)
        let excerpts = TranscriptRetriever.relevantChunks(for: question, in: chunks, limit: 2)
        let tasks = meeting.actionItems.map { item in item.task + (item.owner.map { " (\($0))" } ?? "") }

        let session = LanguageModelSession(instructions: """
        You answer questions about one meeting, using only the notes and transcript excerpts given.
        If the answer is not in them, say that it was not discussed in this meeting.
        Answer in the language of the question, in one to three sentences.
        """)
        let prompt = """
        Meeting: \(meeting.title)
        Summary: \(meeting.summary)
        Decisions: \(meeting.decisions.joined(separator: " / "))
        Action items: \(tasks.joined(separator: " / "))

        Transcript excerpts:
        \(excerpts.joined(separator: "\n---\n"))

        Question: \(question)
        """
        return try await session.respond(to: prompt).content
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Picks the answerer for this launch: canned answers in UI tests, the on-device model otherwise.
enum Answerers {
    static var current: any MeetingAnswerer {
        #if DEBUG
        if UITestSupport.isActive { return UITestSupport.CannedAnswerer() }
        #endif
        return OnDeviceAnswerer()
    }
}
