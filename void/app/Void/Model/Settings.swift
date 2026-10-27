import Foundation
import Security

/// User settings. Plain values live in UserDefaults (bound with @AppStorage in views);
/// the webhook signing secret and auth header live in the Keychain.
enum SettingsKey {
    static let webhookURL = "webhookURL"
    static let includeTranscript = "includeTranscript"
    static let silenceMinutes = "silenceMinutes"
    static let recognitionLocale = "recognitionLocale"
    static let summaryLanguage = "summaryLanguage"
    static let deleteAudioAfterProcessing = "deleteAudioAfterProcessing"
}

enum AppSettings {
    /// Spike D: replaying the app's VAD logic on a real 52-min talk found a 61 s pause,
    /// so a 1-min timeout cut it short. Never allow < 2 min.
    static let silenceMinutesRange = 2...30

    static var webhookURL: URL? {
        guard let raw = UserDefaults.standard.string(forKey: SettingsKey.webhookURL)?
            .trimmingCharacters(in: .whitespaces), !raw.isEmpty,
            // HTTPS only: the payload is the meeting itself, and ATS blocks plain HTTP anyway.
            let url = URL(string: raw), url.scheme?.lowercased() == "https", url.host() != nil
        else { return nil }
        return url
    }

    static var includeTranscript: Bool {
        UserDefaults.standard.bool(forKey: SettingsKey.includeTranscript)
    }

    static var silenceMinutes: Int {
        let value = UserDefaults.standard.integer(forKey: SettingsKey.silenceMinutes)
        return value == 0 ? 3 : min(max(value, silenceMinutesRange.lowerBound), silenceMinutesRange.upperBound)
    }

    static var recognitionLocale: Locale {
        Locale(identifier: UserDefaults.standard.string(forKey: SettingsKey.recognitionLocale) ?? "ko-KR")
    }

    /// Language the summary is written in, independent of the meeting's spoken language.
    static var summaryLanguage: String {
        UserDefaults.standard.string(forKey: SettingsKey.summaryLanguage) ?? "ko"
    }

    static var deleteAudioAfterProcessing: Bool {
        UserDefaults.standard.bool(forKey: SettingsKey.deleteAudioAfterProcessing)
    }
}

/// Minimal Keychain wrapper for small secrets (device-only, never synced).
enum Keychain {
    static let webhookSecret = "webhook.secret"
    static let webhookAuthorization = "webhook.authorization"

    static func string(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Stores `value` (nil or empty deletes). Updates in place, so a failed write never
    /// leaves the old secret deleted. Returns whether the Keychain accepted the change.
    @discardableResult
    static func set(_ value: String?, for key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        guard let value, !value.isEmpty else {
            let status = SecItemDelete(query as CFDictionary)
            return status == errSecSuccess || status == errSecItemNotFound
        }
        let data = Data(value.utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }
}
