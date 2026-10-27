import Foundation

/// The webhook payload, version 1. See docs/PRD.md §5.
public struct MeetingResult: Codable, Sendable, Equatable {
    public enum EndReason: String, Codable, Sendable {
        case manual
        case silenceTimeout = "silence_timeout"
    }

    public struct ActionItem: Codable, Sendable, Equatable {
        public var task: String
        public var owner: String?
        public var due: String?

        public init(task: String, owner: String? = nil, due: String? = nil) {
            self.task = task
            self.owner = owner
            self.due = due
        }

        enum CodingKeys: String, CodingKey {
            case task, owner, due
        }

        /// Writes missing owner/due as explicit `null`, matching the documented payload shape.
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(task, forKey: .task)
            try container.encode(owner, forKey: .owner)
            try container.encode(due, forKey: .due)
        }
    }

    public struct Segment: Codable, Sendable, Equatable {
        public var start: TimeInterval
        public var end: TimeInterval
        public var text: String

        public init(start: TimeInterval, end: TimeInterval, text: String) {
            self.start = start
            self.end = end
            self.text = text
        }
    }

    public static let currentVersion = "1"

    public var version: String
    public var id: String
    public var startedAt: Date
    public var endedAt: Date
    public var endReason: EndReason
    public var language: String
    public var title: String
    public var summary: String
    public var decisions: [String]
    public var actionItems: [ActionItem]
    /// Omitted unless the user opts in, to keep what leaves the device minimal.
    public var transcript: [Segment]?

    public init(
        id: String,
        startedAt: Date,
        endedAt: Date,
        endReason: EndReason,
        language: String,
        title: String,
        summary: String,
        decisions: [String],
        actionItems: [ActionItem],
        transcript: [Segment]? = nil
    ) {
        self.version = Self.currentVersion
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.endReason = endReason
        self.language = language
        self.title = title
        self.summary = summary
        self.decisions = decisions
        self.actionItems = actionItems
        self.transcript = transcript
    }

    enum CodingKeys: String, CodingKey {
        case version, id, language, title, summary, decisions, transcript
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case endReason = "end_reason"
        case actionItems = "action_items"
    }

    /// The canonical encoder: ISO-8601 dates and sorted keys, so the signed bytes are stable.
    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
