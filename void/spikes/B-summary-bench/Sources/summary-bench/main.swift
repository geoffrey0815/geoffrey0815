// Spike B: summarize a Korean meeting transcript entirely on-device with the
// Apple Foundation Models framework, using map-reduce for long meetings.
//
// Usage: swift run -c release summary-bench <transcript.txt> [maxCharsPerChunk]

import Foundation
import FoundationModels
import VoidCore

@Generable
struct ChunkNotes {
    @Guide(description: "이 구간에서 논의된 핵심 내용, 3~6개의 짧은 문장")
    var points: [String]
    @Guide(description: "이 구간에서 확정된 결정사항. 없으면 빈 배열")
    var decisions: [String]
    @Guide(description: "누가 무엇을 하기로 했는지. 없으면 빈 배열")
    var actionItems: [GeneratedActionItem]
}

@Generable
struct GeneratedActionItem {
    @Guide(description: "해야 할 일, 동사로 끝나는 한 문장")
    var task: String
    @Guide(description: "담당자 이름. 언급되지 않았으면 빈 문자열")
    var owner: String
}

@Generable
struct MeetingSummary {
    @Guide(description: "회의 제목, 20자 이내")
    var title: String
    @Guide(description: "회의 전체 요약, 3~5문장")
    var summary: String
    var decisions: [String]
    var actionItems: [GeneratedActionItem]
}

let instructions = """
너는 회의록 작성자다. 주어진 회의 전사본만 근거로 한국어로 정리한다.
전사본에 없는 내용은 절대 만들어내지 않는다. 전사 오류로 보이는 단어는 문맥상 자연스럽게 고친다.
"""

guard CommandLine.arguments.count >= 2 else {
    print("usage: summary-bench <transcript.txt> [maxCharsPerChunk]")
    exit(2)
}

switch SystemLanguageModel.default.availability {
case .available:
    break
case .unavailable(let reason):
    print("on-device model unavailable: \(reason)")
    exit(1)
}

let transcript = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
let budget = CommandLine.arguments.count >= 3 ? Int(CommandLine.arguments[2]) ?? 1_500 : 1_500
let segments = transcript.split(separator: "\n").map { MeetingResult.Segment(start: 0, end: 0, text: String($0)) }
let chunks = TranscriptChunker.chunks(of: segments, maxCharacters: budget)
print("transcript: \(transcript.count) chars → \(chunks.count) chunks of ≤\(budget)")

let start = Date()

// Map: each chunk gets a fresh session so earlier chunks don't eat the context window.
var notes: [ChunkNotes] = []
for (index, chunk) in chunks.enumerated() {
    let session = LanguageModelSession(instructions: instructions)
    let response = try await session.respond(
        to: "다음은 회의 전사본의 \(index + 1)/\(chunks.count) 구간이다. 정리하라.\n\n\(chunk)",
        generating: ChunkNotes.self
    )
    notes.append(response.content)
    print(String(format: "  chunk %d/%d  %.1fs", index + 1, chunks.count, Date().timeIntervalSince(start)))
}

// Reduce hierarchically (same as the app's Summarizer): merge groups of notes that fit
// the budget, at least two at a time, until everything fits one final request.
func render(_ notes: [ChunkNotes]) -> String {
    notes.map { note in
        """
        핵심: \(note.points.joined(separator: " / "))
        결정: \(note.decisions.joined(separator: " / "))
        할 일: \(note.actionItems.map { "\($0.task) (\($0.owner))" }.joined(separator: " / "))
        """
    }.joined(separator: "\n\n")
}

var round = 0
while notes.count > 1, render(notes).count > budget {
    round += 1
    var groups: [[ChunkNotes]] = []
    var current: [ChunkNotes] = []
    for note in notes {
        if current.count >= 2, render(current + [note]).count > budget {
            groups.append(current)
            current = []
        }
        current.append(note)
    }
    if !current.isEmpty { groups.append(current) }

    var merged: [ChunkNotes] = []
    for group in groups {
        guard group.count > 1 else {
            merged.append(contentsOf: group)
            continue
        }
        let session = LanguageModelSession(instructions: instructions)
        merged.append(try await session.respond(
            to: "다음은 한 회의를 구간별로 정리한 메모다. 중복을 합쳐 하나의 메모로 정리하라.\n\n\(render(group))",
            generating: ChunkNotes.self
        ).content)
    }
    print(String(format: "  reduce round %d: %d → %d notes  %.1fs", round, notes.count, merged.count, Date().timeIntervalSince(start)))
    notes = merged
}

let session = LanguageModelSession(instructions: instructions)
let final = try await session.respond(
    to: "다음은 한 회의를 구간별로 정리한 메모다. 중복을 합쳐 최종 회의록을 만들어라.\n\n\(render(notes))",
    generating: MeetingSummary.self
).content
let elapsed = Date().timeIntervalSince(start)

let result = MeetingResult(
    id: "mtg_spike",
    startedAt: Date(),
    endedAt: Date(),
    endReason: .manual,
    language: "ko",
    title: final.title,
    summary: final.summary,
    decisions: final.decisions,
    actionItems: final.actionItems.map { .init(task: $0.task, owner: $0.owner.isEmpty ? nil : $0.owner) }
)
let encoder = MeetingResult.makeEncoder()
encoder.outputFormatting.insert(.prettyPrinted)
print(String(decoding: try encoder.encode(result), as: UTF8.self))
print(String(format: "total: %.1fs", elapsed))
