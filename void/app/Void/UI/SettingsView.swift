import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKey.webhookURL) private var webhookURL = ""
    @AppStorage(SettingsKey.includeTranscript) private var includeTranscript = false
    @AppStorage(SettingsKey.silenceMinutes) private var silenceMinutes = 3
    @AppStorage(SettingsKey.recognitionLocale) private var recognitionLocale = "ko-KR"
    @AppStorage(SettingsKey.summaryLanguage) private var summaryLanguage = "ko"
    @AppStorage(SettingsKey.deleteAudioAfterProcessing) private var deleteAudio = false

    @State private var secret = Keychain.string(for: Keychain.webhookSecret) ?? ""
    @State private var authorization = Keychain.string(for: Keychain.webhookAuthorization) ?? ""

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
                } header: {
                    Text("Webhook")
                } footer: {
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
                    Toggle("처리 후 오디오 삭제", isOn: $deleteAudio)
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
                    Keychain.set(secret, for: Keychain.webhookSecret)
                    Keychain.set(authorization, for: Keychain.webhookAuthorization)
                    dismiss()
                }
                .fontWeight(.semibold)
                .tint(Theme.ink)
            }
        }
    }
}
