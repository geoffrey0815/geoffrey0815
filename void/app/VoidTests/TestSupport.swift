import Foundation
import SwiftData
@testable import VoidMain

/// Serves canned HTTP responses and records requests, so webhook delivery runs for real
/// (URLSession, headers, body) without a network.
final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var statusCode = 200
    nonisolated(unsafe) static var requests: [(request: URLRequest, body: Data)] = []

    static func reset(statusCode: Int = 200) {
        self.statusCode = statusCode
        requests = []
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requests.append((request, Self.body(of: request)))
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.statusCode, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// URLSession moves `httpBody` into a stream before a protocol sees the request.
    private static func body(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

struct FakeTranscriber: Transcriber {
    var segments: [MeetingResult.Segment] = [
        .init(start: 0, end: 5, text: "4분기 로드맵 리뷰를 시작하겠습니다."),
        .init(start: 5, end: 12, text: "출시는 12월 첫째 주로 확정합니다."),
    ]
    var failure: (any Error)?

    func transcribe(fileAt url: URL, locale: Locale) async throws -> [MeetingResult.Segment] {
        if let failure { throw failure }
        return segments
    }
}

struct FakeSummarizer: MeetingSummarizer {
    var failure: (any Error)?

    func summarize(_ segments: [MeetingResult.Segment], outputLanguage: String) async throws -> MeetingSummary {
        if let failure { throw failure }
        return MeetingSummary(
            title: "Q4 로드맵 리뷰",
            summary: "출시 일정을 확정했다.",
            decisions: ["출시는 12월 첫째 주"],
            actionItems: [.init(task: "공지 작성하기", owner: "민지")]
        )
    }
}

struct TestError: LocalizedError {
    var errorDescription: String? { "test failure" }
}
