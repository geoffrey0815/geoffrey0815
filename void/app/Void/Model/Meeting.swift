import Foundation
import OSLog
import SwiftData
import VoidCore

@Model
final class Meeting {
    enum Status: String, Codable {
        case recording, transcribing, summarizing, ready, failed
    }

    enum Delivery: String, Codable {
        case notConfigured, pending, delivered, failed
    }

    @Attribute(.unique) var id: String
    var startedAt: Date
    var endedAt: Date?
    var endReasonRaw: String?
    var statusRaw: String
    var deliveryRaw: String
    var deliveryAttempts: Int = 0
    /// When a pending delivery should be retried; nil when nothing is scheduled.
    var nextDeliveryAt: Date?
    var errorMessage: String?

    var language: String
    var title: String
    var summary: String
    var decisions: [String]
    var actionItems: [MeetingResult.ActionItem]
    var transcript: [MeetingResult.Segment]

    /// File name inside `Meeting.recordingsDirectory`; nil once the audio is deleted.
    var audioFileName: String?

    init(startedAt: Date = .now, language: String) {
        let id = "mtg_" + UUID().uuidString.lowercased()
        self.id = id
        self.startedAt = startedAt
        self.statusRaw = Status.recording.rawValue
        self.deliveryRaw = Delivery.notConfigured.rawValue
        self.language = language
        self.title = ""
        self.summary = ""
        self.decisions = []
        self.actionItems = []
        self.transcript = []
        self.audioFileName = "\(id).m4a"
    }

    var status: Status {
        get { Status(rawValue: statusRaw) ?? .failed }
        set { statusRaw = newValue.rawValue }
    }

    var delivery: Delivery {
        get { Delivery(rawValue: deliveryRaw) ?? .failed }
        set { deliveryRaw = newValue.rawValue }
    }

    var endReason: MeetingResult.EndReason? {
        get { endReasonRaw.flatMap(MeetingResult.EndReason.init(rawValue:)) }
        set { endReasonRaw = newValue?.rawValue }
    }

    var audioURL: URL? {
        audioFileName.map { Self.recordingsDirectory.appendingPathComponent($0) }
    }

    var displayTitle: String {
        title.isEmpty ? startedAt.formatted(date: .abbreviated, time: .shortened) : title
    }

    func result(includeTranscript: Bool) -> MeetingResult {
        MeetingResult(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt ?? startedAt,
            endReason: endReason ?? .manual,
            language: language,
            title: title,
            summary: summary,
            decisions: decisions,
            actionItems: actionItems,
            transcript: includeTranscript ? transcript : nil
        )
    }

    /// Recordings live in Application Support with complete file protection,
    /// excluded from iCloud backup so audio never leaves the device.
    static let recordingsDirectory: URL = {
        var url = URL.applicationSupportDirectory.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
        return url
    }()
}

@MainActor
enum Persistence {
    private static let logger = Logger(subsystem: "void", category: "persistence")

    /// The store lives in its own folder excluded from iCloud/device backup, like the
    /// recordings: transcripts and summaries must not leave the device that way either.
    static let container: ModelContainer = {
        var directory = URL.applicationSupportDirectory.appendingPathComponent("Store", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? directory.setResourceValues(values)
        do {
            let configuration = ModelConfiguration(url: directory.appendingPathComponent("void.store"))
            return try ModelContainer(for: Meeting.self, configurations: configuration)
        } catch {
            fatalError("Could not open the meeting store: \(error)")
        }
    }()

    /// Saves and logs failures (disk full is the realistic case). Returns whether it saved.
    @discardableResult
    static func save(_ context: ModelContext) -> Bool {
        do {
            try context.save()
            return true
        } catch {
            logger.error("SwiftData save failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
