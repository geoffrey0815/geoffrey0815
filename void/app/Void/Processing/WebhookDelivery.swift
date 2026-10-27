import BackgroundTasks
import Foundation
import VoidCore

/// Sends a finished meeting to the user's webhook. The only network call the app makes.
/// One attempt per call; the retry schedule is persisted on the Meeting by the pipeline.
struct WebhookDelivery {
    enum Outcome: Sendable {
        case delivered
        /// Worth retrying later (network error, 5xx, 408, 429).
        case retryable(String)
        /// The receiver rejected the payload; retrying will not help.
        case rejected(String)
    }

    /// Backoff between persisted attempts: 30 s, 1 m, 2 m … capped at 6 h, 8 attempts.
    static let policy = RetryPolicy()

    /// Injected in tests to stub the network.
    var session: URLSession = .shared

    /// BGAppRefreshTask identifier; must match BGTaskSchedulerPermittedIdentifiers in Info.plist.
    static let refreshTaskID = (Bundle.main.bundleIdentifier ?? "void") + ".webhook-retry"

    func send(_ result: MeetingResult, to url: URL, secret: String?, authorization: String?) async -> Outcome {
        let builder = WebhookRequestBuilder(
            url: url,
            extraHeaders: authorization.map { ["Authorization": $0] } ?? [:],
            signer: secret.map(WebhookSigner.init(secret:))
        )
        do {
            let request = try builder.makeRequest(for: result)
            let (_, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if (200..<300).contains(status) { return .delivered }
            return RetryPolicy.isRetryable(statusCode: status) ? .retryable("HTTP \(status)") : .rejected("HTTP \(status)")
        } catch {
            return .retryable(error.localizedDescription)
        }
    }

    /// Asks the system to wake the app around `date` to retry. Best effort: iOS decides when.
    static func scheduleBackgroundRetry(at date: Date) {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        request.earliestBeginDate = date
        try? BGTaskScheduler.shared.submit(request)
    }
}
