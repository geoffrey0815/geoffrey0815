import SwiftUI
import VoidCore

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKey.webhookURL) private var webhookURL = ""
    @AppStorage(SettingsKey.includeTranscript) private var includeTranscript = false
    @AppStorage(SettingsKey.silenceMinutes) private var silenceMinutes = 3
    @AppStorage(SettingsKey.recognitionLocale) private var recognitionLocale = "ko-KR"
    @AppStorage(SettingsKey.summaryLanguage) private var summaryLanguage = "ko"
    @AppStorage(SettingsKey.audioRetentionDays) private var audioRetentionDays = -1

    @State private var secret = Keychain.string(for: Keychain.webhookSecret) ?? ""
    @State private var authorization = Keychain.string(for: Keychain.webhookAuthorization) ?? ""
    @State private var saveError: String?
    @State private var testResult: String?
    @State private var isTesting = false

    private var webhookURLIsInvalid: Bool {
        !webhookURL.trimmingCharacters(in: .whitespaces).isEmpty && AppSettings.webhookURL == nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://", text: $webhookURL)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("서명 비밀키 (선택)", text: $secret)
                    SecureField("Authorization 헤더 (선택)", text: $authorization)
                    Toggle("원문 포함", isOn: $includeTranscript)
                    Button(isTesting ? "보내는 중…" : "테스트 전송") {
                        Task { await sendTest() }
                    }
                    .disabled(AppSettings.webhookURL == nil || isTesting)
                    .tint(Theme.ink)
                } header: {
                    Text("Webhook")
                } footer: {
                    if webhookURLIsInvalid {
                        Text("https:// 로 시작하는 주소만 쓸 수 있습니다.").fontWeight(.semibold)
                    }
                    if let saveError {
                        Text(saveError).fontWeight(.semibold)
                    }
                    if let testResult {
                        Text(testResult).fontWeight(.semibold)
                    }
                    Text("녹음이 끝나면 요약을 이 주소로 보냅니다. 앱이 기기 밖으로 보내는 데이터는 이것뿐입니다. 비밀키를 넣으면 X-Void-Signature 헤더로 서명합니다.")
                }

                Section {
                    Stepper(value: $silenceMinutes, in: AppSettings.silenceMinutesRange) {
                        LabeledContent("무음 자동 종료", value: "\(silenceMinutes)분")
                    }
                } footer: {
                    Text("말소리 없이 이 시간이 지나면 녹음을 멈춥니다. 30초 전에 알려 드려요.")
                }

                Section("언어") {
                    Picker("받아쓰기", selection: $recognitionLocale) {
                        Text("한국어").tag("ko-KR")
                        Text("English").tag("en-US")
                    }
                    Picker("요약", selection: $summaryLanguage) {
                        Text("한국어").tag("ko")
                        Text("English").tag("en")
                    }
                }

                Section {
                    Picker("오디오 보관", selection: $audioRetentionDays) {
                        Text("처리 후 바로 삭제").tag(0)
                        Text("7일").tag(7)
                        Text("30일").tag(30)
                        Text("계속 보관").tag(-1)
                    }
                } header: {
                    Text("개인정보")
                } footer: {
                    Text("받아쓰기와 요약은 모두 이 기기 안에서 처리됩니다. 언어별 받아쓰기 모델만 처음 한 번 Apple에서 내려받습니다.")
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("완료") {
                    let saved = Keychain.set(secret, for: Keychain.webhookSecret)
                        && Keychain.set(authorization, for: Keychain.webhookAuthorization)
                    if saved {
                        dismiss()
                    } else {
                        saveError = "비밀키를 저장하지 못했습니다. 다시 시도해 주세요."
                    }
                }
                .fontWeight(.semibold)
                .tint(Theme.ink)
            }
        }
    }

    /// Sends a sample payload with the values on screen (saved or not), so the user can
    /// check URL, auth header and signature before a real meeting depends on them.
    private func sendTest() async {
        guard let url = AppSettings.webhookURL else { return }
        isTesting = true
        defer { isTesting = false }
        let sample = MeetingResult(
            id: "mtg_test_" + UUID().uuidString.lowercased(),
            startedAt: .now.addingTimeInterval(-30 * 60),
            endedAt: .now,
            endReason: .manual,
            language: "ko",
            title: "void 테스트",
            summary: "webhook 연결을 확인하는 테스트 메시지입니다.",
            decisions: [],
            actionItems: [.init(task: "webhook 수신 확인하기")]
        )
        let outcome = await WebhookDelivery().send(
            sample,
            to: url,
            secret: secret.isEmpty ? nil : secret,
            authorization: authorization.isEmpty ? nil : authorization
        )
        switch outcome {
        case .delivered:
            testResult = "테스트 전송 성공"
        case .retryable(let reason), .rejected(let reason):
            testResult = "테스트 전송 실패: \(reason)"
        }
    }
}
