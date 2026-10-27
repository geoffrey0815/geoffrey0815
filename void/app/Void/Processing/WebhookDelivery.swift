import Foundation
import VoidCore

/// Sends a finished meeting to the user's webhook. The only network call the app makes.
struct WebhookDelivery {
    enum Outcome: Sendable {
        case delivered
        case failed(String)
    }

    /// In-process retries only. TODO: persist the queue and retry from a background
    /// URLSession / BGTask so deliveries survive the app being suspended.
    var policy = RetryPolicy(maxAttempts: 4, baseDelay: 5, maxDelay: 60)

    func deliver(_ result: MeetingResult, to url: URL, secret: String?, authorization: String?) async -> Outcome {
        let builder = WebhookRequestBuilder(
            url: url,
            extraHeaders: authorization.map { ["Authorization": $0] } ?? [:],
            signer: secret.map(WebhookSigner.init(secret:))
        )
        var attempt = 0
        while true {
            attempt += 1
            let failure: String
            do {
                // Re-sign on every attempt so the timestamp stays fresh.
                let request = try builder.makeRequest(for: result)
                let (_, response) = try await URLSession.shared.data(for: request)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                if (200..<300).contains(status) { return .delivered }
                failure = "HTTP \(status)"
                if !RetryPolicy.isRetryable(statusCode: status) { return .failed(failure) }
            } catch {
                failure = error.localizedDescription
            }
            guard let delay = policy.delay(afterAttempt: attempt) else { return .failed(failure) }
            try? await Task.sleep(for: .seconds(delay))
        }
    }
}
