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
    /// Spike D: the longest natural pause in a real 52-min talk was 56 s, so never allow < 2 min.
    static let silenceMinutesRange = 2...30

    static var webhookURL: URL? {
        guard let raw = UserDefaults.standard.string(forKey: SettingsKey.webhookURL)?
            .trimmingCharacters(in: .whitespaces), !raw.isEmpty,
            let url = URL(string: raw), url.scheme == "https" || url.scheme == "http"
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

    static func set(_ value: String?, for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
        guard let value, !value.isEmpty else { return }
        var attributes = query
        attributes[kSecValueData as String] = Data(value.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }
}
