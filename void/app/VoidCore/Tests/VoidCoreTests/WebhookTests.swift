import Foundation
import Testing
@testable import VoidCore

@Suite struct WebhookTests {
    let result = MeetingResult(
        id: "mtg_test",
        startedAt: Date(timeIntervalSince1970: 1_800_000_000),
        endedAt: Date(timeIntervalSince1970: 1_800_002_520),
        endReason: .silenceTimeout,
        language: "ko",
        title: "Q4 로드맵 리뷰",
        summary: "요약",
        decisions: ["출시는 12월"],
        actionItems: [.init(task: "견적 받기", owner: "민지")]
    )

    @Test func payloadUsesSnakeCaseAndOmitsTranscriptByDefault() throws {
        let data = try MeetingResult.makeEncoder().encode(result)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["end_reason"] as? String == "silence_timeout")
        #expect(json["action_items"] != nil)
        #expect(json["started_at"] as? String == "2027-01-15T08:00:00Z")
        #expect(json["transcript"] == nil)
        #expect(json["version"] as? String == "1")
        let item = try #require((json["action_items"] as? [[String: Any]])?.first)
        #expect(item["due"] is NSNull) // nil is written as null, not dropped
        #expect(item["owner"] as? String == "민지")
    }

    @Test func payloadRoundTrips() throws {
        let data = try MeetingResult.makeEncoder().encode(result)
        let decoded = try MeetingResult.makeDecoder().decode(MeetingResult.self, from: data)
        #expect(decoded == result)
    }

    @Test func signatureMatchesKnownVector() {
        // printf '1700000000.{}' | openssl dgst -sha256 -hmac secret
        let signer = WebhookSigner(secret: "secret")
        let signature = signer.signature(for: Data("{}".utf8), timestamp: 1_700_000_000)
        #expect(signature == "sha256=b8569b78799ff9e3cbff0fc2d63a33a2b57f3282abd07c37ae5e8e7d79a5f163")
    }

    @Test func signatureVerification() {
        let signer = WebhookSigner(secret: "secret")
        let body = Data("{\"a\":1}".utf8)
        let signature = signer.signature(for: body, timestamp: 42)
        #expect(signer.isValid(signature: signature, body: body, timestamp: 42))
        #expect(!signer.isValid(signature: signature, body: body, timestamp: 43))
        #expect(!signer.isValid(signature: signature, body: Data("{\"a\":2}".utf8), timestamp: 42))
        #expect(!WebhookSigner(secret: "other").isValid(signature: signature, body: body, timestamp: 42))
        #expect(!signer.isValid(signature: "sha256=zz", body: body, timestamp: 42))
    }

    @Test func requestCarriesHeaders() throws {
        let builder = WebhookRequestBuilder(
            url: URL(string: "https://example.com/hook")!,
            extraHeaders: ["Authorization": "Bearer t", "Content-Type": "text/plain"],
            signer: WebhookSigner(secret: "secret")
        )
        let request = try builder.makeRequest(for: result, now: Date(timeIntervalSince1970: 100))
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer t")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Idempotency-Key") == "mtg_test")
        #expect(request.value(forHTTPHeaderField: WebhookSigner.timestampHeader) == "100")
        let signature = try #require(request.value(forHTTPHeaderField: WebhookSigner.signatureHeader))
        #expect(WebhookSigner(secret: "secret").isValid(signature: signature, body: try #require(request.httpBody), timestamp: 100))
    }

    @Test func retryBackoff() {
        let policy = RetryPolicy(maxAttempts: 4, baseDelay: 30, maxDelay: 100)
        #expect(policy.delay(afterAttempt: 1) == 30)
        #expect(policy.delay(afterAttempt: 2) == 60)
        #expect(policy.delay(afterAttempt: 3) == 100)
        #expect(policy.delay(afterAttempt: 4) == nil)
        #expect(RetryPolicy.isRetryable(statusCode: 503))
        #expect(RetryPolicy.isRetryable(statusCode: 429))
        #expect(!RetryPolicy.isRetryable(statusCode: 404))
        #expect(!RetryPolicy.isRetryable(statusCode: 204))
    }

    @Test func chunkerRespectsBudgetAndOrder() {
        let segments = (0..<10).map { MeetingResult.Segment(start: Double($0), end: Double($0 + 1), text: String(repeating: "가", count: 40)) }
        let chunks = TranscriptChunker.chunks(of: segments, maxCharacters: 100)
        #expect(chunks.allSatisfy { $0.count <= 100 })
        #expect(chunks.joined(separator: "\n").filter { $0 == "가" }.count == 400)
    }

    @Test func chunkerSplitsOversizedSegmentAtSentenceEnd() {
        let sentence = "이번 분기 목표를 정했다. " // 15 characters
        let text = String(repeating: sentence, count: 10)
        let chunks = TranscriptChunker.chunks(of: [.init(start: 0, end: 1, text: text)], maxCharacters: 100)
        #expect(chunks.allSatisfy { $0.count <= 100 && $0.hasSuffix(".") })
        #expect(chunks.joined(separator: " ") == text.trimmingCharacters(in: .whitespaces))
    }

    @Test func chunkerHardSplitsOversizedSegment() {
        let segments = [MeetingResult.Segment(start: 0, end: 1, text: String(repeating: "a", count: 250))]
        #expect(TranscriptChunker.chunks(of: segments, maxCharacters: 100).map(\.count) == [100, 100, 50])
    }
}
