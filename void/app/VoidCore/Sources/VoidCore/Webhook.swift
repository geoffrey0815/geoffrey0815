import CryptoKit
import Foundation

/// Signs webhook bodies so receivers can reject forged requests.
///
/// Header: `X-Void-Signature: sha256=<hex HMAC-SHA256(timestamp + "." + body, secret)>`
/// plus `X-Void-Timestamp: <unix seconds>`. Including the timestamp lets receivers
/// drop replays older than a few minutes.
public struct WebhookSigner: Sendable {
    public static let signatureHeader = "X-Void-Signature"
    public static let timestampHeader = "X-Void-Timestamp"

    private let key: SymmetricKey

    public init(secret: String) {
        self.key = SymmetricKey(data: Data(secret.utf8))
    }

    public func signature(for body: Data, timestamp: Int) -> String {
        var message = Data("\(timestamp).".utf8)
        message.append(body)
        let mac = HMAC<SHA256>.authenticationCode(for: message, using: key)
        return "sha256=" + mac.map { String(format: "%02x", $0) }.joined()
    }

    public func isValid(signature: String, body: Data, timestamp: Int) -> Bool {
        // Compare MACs in constant time rather than comparing strings.
        guard signature.hasPrefix("sha256="),
              let provided = Data(hex: String(signature.dropFirst("sha256=".count))) else { return false }
        var message = Data("\(timestamp).".utf8)
        message.append(body)
        return HMAC<SHA256>.isValidAuthenticationCode(provided, authenticating: message, using: key)
    }
}

/// Builds the outgoing request. Sending and the retry queue live in the app,
/// because they depend on background URLSession configuration.
public struct WebhookRequestBuilder: Sendable {
    public var url: URL
    public var extraHeaders: [String: String]
    public var signer: WebhookSigner?

    public init(url: URL, extraHeaders: [String: String] = [:], signer: WebhookSigner? = nil) {
        self.url = url
        self.extraHeaders = extraHeaders
        self.signer = signer
    }

    public func makeRequest(for result: MeetingResult, now: Date = .now) throws -> URLRequest {
        let body = try MeetingResult.makeEncoder().encode(result)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        for (name, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: name)
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(result.id, forHTTPHeaderField: "Idempotency-Key")
        if let signer {
            let timestamp = Int(now.timeIntervalSince1970)
            request.setValue(String(timestamp), forHTTPHeaderField: WebhookSigner.timestampHeader)
            request.setValue(signer.signature(for: body, timestamp: timestamp), forHTTPHeaderField: WebhookSigner.signatureHeader)
        }
        return request
    }
}

/// Exponential backoff for failed deliveries.
public struct RetryPolicy: Sendable, Equatable {
    public var maxAttempts: Int
    public var baseDelay: TimeInterval
    public var maxDelay: TimeInterval

    public init(maxAttempts: Int = 8, baseDelay: TimeInterval = 30, maxDelay: TimeInterval = 6 * 3600) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
    }

    /// Delay before retry number `attempt` (1-based, counting the failed attempts so far),
    /// or nil when delivery should be given up.
    public func delay(afterAttempt attempt: Int) -> TimeInterval? {
        guard attempt >= 1, attempt < maxAttempts else { return nil }
        return min(baseDelay * pow(2, Double(attempt - 1)), maxDelay)
    }

    /// Whether an HTTP status is worth retrying; 4xx other than 408/429 means the receiver rejected it.
    public static func isRetryable(statusCode: Int) -> Bool {
        switch statusCode {
        case 200..<300: false
        case 408, 429: true
        case 400..<500: false
        default: true
        }
    }
}

extension Data {
    init?(hex: String) {
        guard hex.count.isMultiple(of: 2) else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        self.init(bytes)
    }
}
