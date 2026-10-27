import SwiftData
import XCTest
@testable import VoidMain

/// End-to-end pipeline behaviour with fake on-device models and a stubbed network:
/// recording file → transcript → summary → signed webhook, plus retries and retention.
@MainActor
final class PipelineTests: XCTestCase {
    private var container: ModelContainer!
    private var pipeline: ProcessingPipeline!
    private let webhook = "https://hooks.example.com/void"
    private let secret = "s3cret"

    override func setUp() async throws {
        container = try ModelContainer(for: Meeting.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        pipeline = ProcessingPipeline(container: container)
        pipeline.transcriber = FakeTranscriber()
        pipeline.summarizer = FakeSummarizer()
        var delivery = WebhookDelivery()
        delivery.session = StubURLProtocol.makeSession()
        pipeline.delivery = delivery
        StubURLProtocol.reset()

        let defaults = UserDefaults.standard
        defaults.set(webhook, forKey: SettingsKey.webhookURL)
        defaults.set(false, forKey: SettingsKey.includeTranscript)
        defaults.removeObject(forKey: SettingsKey.audioRetentionDays)
        XCTAssertTrue(Keychain.set(secret, for: Keychain.webhookSecret))
        Keychain.set(nil, for: Keychain.webhookAuthorization)
    }

    override func tearDown() async throws {
        for key in [SettingsKey.webhookURL, SettingsKey.includeTranscript, SettingsKey.audioRetentionDays] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        Keychain.set(nil, for: Keychain.webhookSecret)
    }

    /// A finished recording waiting for processing, with a real (dummy) audio file.
    private func makeMeeting(status: Meeting.Status = .transcribing, startedAt: Date = .now.addingTimeInterval(-600)) throws -> Meeting {
        let meeting = Meeting(startedAt: startedAt, language: "ko-KR")
        meeting.endedAt = startedAt.addingTimeInterval(300)
        meeting.endReason = .manual
        meeting.status = status
        try Data("audio".utf8).write(to: XCTUnwrap(meeting.audioURL))
        container.mainContext.insert(meeting)
        try container.mainContext.save()
        return meeting
    }

    func testProcessTranscribesSummarizesAndDeliversSignedWebhook() async throws {
        let meeting = try makeMeeting()
        await pipeline.process(meetingID: meeting.id)

        XCTAssertEqual(meeting.status, .ready)
        XCTAssertEqual(meeting.delivery, .delivered)
        XCTAssertEqual(meeting.title, "Q4 로드맵 리뷰")
        XCTAssertEqual(meeting.transcript.count, 2)
        XCTAssertNil(meeting.errorMessage)

        let sent = try XCTUnwrap(StubURLProtocol.requests.first)
        XCTAssertEqual(StubURLProtocol.requests.count, 1)
        XCTAssertEqual(sent.request.url?.absoluteString, webhook)
        XCTAssertEqual(sent.request.httpMethod, "POST")
        XCTAssertEqual(sent.request.value(forHTTPHeaderField: "Idempotency-Key"), meeting.id)

        // The receiver can verify the signature with the shared secret.
        let signature = try XCTUnwrap(sent.request.value(forHTTPHeaderField: WebhookSigner.signatureHeader))
        let timestamp = try XCTUnwrap(Int(XCTUnwrap(sent.request.value(forHTTPHeaderField: WebhookSigner.timestampHeader))))
        XCTAssertTrue(WebhookSigner(secret: secret).isValid(signature: signature, body: sent.body, timestamp: timestamp))

        let payload = try MeetingResult.makeDecoder().decode(MeetingResult.self, from: sent.body)
        XCTAssertEqual(payload.id, meeting.id)
        XCTAssertEqual(payload.decisions, ["출시는 12월 첫째 주"])
        XCTAssertNil(payload.transcript, "transcript is opt-in")
    }

    func testTranscriptIsIncludedWhenOptedIn() async throws {
        UserDefaults.standard.set(true, forKey: SettingsKey.includeTranscript)
        let meeting = try makeMeeting()
        await pipeline.process(meetingID: meeting.id)
        let body = try XCTUnwrap(StubURLProtocol.requests.first?.body)
        XCTAssertEqual(try MeetingResult.makeDecoder().decode(MeetingResult.self, from: body).transcript?.count, 2)
    }

    func testLiveTranscriptSkipsFileTranscription() async throws {
        pipeline.transcriber = FakeTranscriber(failure: TestError())
        let meeting = try makeMeeting()
        await pipeline.process(meetingID: meeting.id, liveTranscript: [.init(start: 0, end: 3, text: "실시간 받아쓰기")])
        XCTAssertEqual(meeting.status, .ready)
        XCTAssertEqual(meeting.transcript.map(\.text), ["실시간 받아쓰기"])
    }

    func testSummaryFailureMarksFailedAndReprocessRecovers() async throws {
        pipeline.summarizer = FakeSummarizer(failure: TestError())
        let meeting = try makeMeeting()
        await pipeline.process(meetingID: meeting.id)
        XCTAssertEqual(meeting.status, .failed)
        XCTAssertEqual(meeting.errorMessage, "test failure")
        XCTAssertTrue(StubURLProtocol.requests.isEmpty, "nothing is sent for a failed meeting")

        pipeline.summarizer = FakeSummarizer()
        await pipeline.reprocess(meetingID: meeting.id)
        XCTAssertEqual(meeting.status, .ready)
        XCTAssertEqual(meeting.delivery, .delivered)
    }

    func testServerErrorSchedulesPersistedRetry() async throws {
        StubURLProtocol.reset(statusCode: 503)
        let meeting = try makeMeeting()
        await pipeline.process(meetingID: meeting.id)
        XCTAssertEqual(meeting.status, .ready)
        XCTAssertEqual(meeting.delivery, .pending)
        XCTAssertEqual(meeting.deliveryAttempts, 1)
        XCTAssertGreaterThan(try XCTUnwrap(meeting.nextDeliveryAt), .now)

        // Once due and the receiver recovers, the retry succeeds and clears the error.
        StubURLProtocol.reset(statusCode: 200)
        meeting.nextDeliveryAt = .now.addingTimeInterval(-1)
        await pipeline.retryDueDeliveries()
        XCTAssertEqual(meeting.delivery, .delivered)
        XCTAssertNil(meeting.errorMessage)
    }

    func testClientErrorIsNotRetried() async throws {
        StubURLProtocol.reset(statusCode: 404)
        let meeting = try makeMeeting()
        await pipeline.process(meetingID: meeting.id)
        XCTAssertEqual(meeting.delivery, .failed)
        XCTAssertNil(meeting.nextDeliveryAt)
    }

    func testPlainHTTPWebhookIsNeverUsed() async throws {
        UserDefaults.standard.set("http://hooks.example.com/void", forKey: SettingsKey.webhookURL)
        XCTAssertNil(AppSettings.webhookURL)
        let meeting = try makeMeeting()
        await pipeline.process(meetingID: meeting.id)
        XCTAssertEqual(meeting.delivery, .notConfigured)
        XCTAssertTrue(StubURLProtocol.requests.isEmpty)
    }

    func testImmediateRetentionDeletesAudioAfterProcessing() async throws {
        UserDefaults.standard.set(0, forKey: SettingsKey.audioRetentionDays)
        let meeting = try makeMeeting()
        let url = try XCTUnwrap(meeting.audioURL)
        await pipeline.process(meetingID: meeting.id)
        XCTAssertNil(meeting.audioFileName)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testPurgeDeletesOnlyExpiredAudioOfProcessedMeetings() async throws {
        UserDefaults.standard.set(7, forKey: SettingsKey.audioRetentionDays)
        let old = try makeMeeting(status: .ready, startedAt: .now.addingTimeInterval(-10 * 86_400))
        let recent = try makeMeeting(status: .ready, startedAt: .now.addingTimeInterval(-1 * 86_400))
        let failed = try makeMeeting(status: .failed, startedAt: .now.addingTimeInterval(-10 * 86_400))
        let oldURL = try XCTUnwrap(old.audioURL)

        pipeline.purgeExpiredAudio()

        XCTAssertNil(old.audioFileName)
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldURL.path))
        XCTAssertNotNil(recent.audioFileName, "within retention")
        XCTAssertNotNil(failed.audioFileName, "kept for reprocessing")
    }

    func testZeroRetentionClearsAlreadyProcessedAudio() async throws {
        UserDefaults.standard.set(0, forKey: SettingsKey.audioRetentionDays)
        let processed = try makeMeeting(status: .ready)
        pipeline.purgeExpiredAudio()
        XCTAssertNil(processed.audioFileName)
    }

    func testRetentionCountsFromProcessingNotRecording() async throws {
        UserDefaults.standard.set(7, forKey: SettingsKey.audioRetentionDays)
        let reprocessed = try makeMeeting(status: .ready, startedAt: .now.addingTimeInterval(-30 * 86_400))
        reprocessed.processedAt = .now.addingTimeInterval(-86_400)
        pipeline.purgeExpiredAudio()
        XCTAssertNotNil(reprocessed.audioFileName, "processed yesterday, so still within 7 days")
    }

    func testMissingAudioFileClearsStaleReference() async throws {
        UserDefaults.standard.set(7, forKey: SettingsKey.audioRetentionDays)
        let meeting = try makeMeeting(status: .ready, startedAt: .now.addingTimeInterval(-10 * 86_400))
        try FileManager.default.removeItem(at: XCTUnwrap(meeting.audioURL))
        pipeline.purgeExpiredAudio()
        XCTAssertNil(meeting.audioFileName)
        XCTAssertNil(meeting.errorMessage)
    }

    func testDefaultRetentionKeepsAudio() async throws {
        let meeting = try makeMeeting(status: .ready, startedAt: .now.addingTimeInterval(-400 * 86_400))
        pipeline.purgeExpiredAudio()
        XCTAssertNotNil(meeting.audioFileName)
    }
}
