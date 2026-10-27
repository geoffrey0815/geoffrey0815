# void iOS 앱

## 처음 실행하기 (Mac)

```bash
brew install xcodegen
cd void/app
# 1) project.yml 의 VOID_BUNDLE_ID 를 내 것으로 변경 (예: com.geoffrey.void)
xcodegen            # Void.xcodeproj 생성 (생성물은 git에 올리지 않음)
open Void.xcodeproj
```

Xcode에서 *Signing & Capabilities* → Team 선택 (Void, VoidWidgets 두 타깃 모두) → 실기기로 실행.

- 요구사항: Xcode 26, iOS 26 실기기, Apple Intelligence 지원 기기(요약). 시뮬레이터는 마이크·Live Activity 테스트에 부적합.
- 핵심 로직 테스트: `cd VoidCore && swift test`

> ⚠️ 이 뼈대는 Xcode 없이 작성되어 **아직 한 번도 컴파일되지 않았다.** 첫 빌드에서 나오는 오류는 대부분 API 시그니처 차이일 것이다.
> 특히 확인할 곳: `Transcriber.swift`(SpeechAnalyzer), `Summarizer.swift`(Foundation Models), `RecordingIntents.swift`(AudioRecordingIntent).

## 구조

```
app/
├── project.yml              XcodeGen 정의 (앱 + 위젯 확장 + VoidCore)
├── VoidCore/                플랫폼 독립 로직 (테스트 있음)
├── Shared/                  앱·위젯 양쪽에 컴파일
│   ├── RecordingIntents     ToggleRecording / StopRecording / KeepRecording
│   ├── RecordingAttributes  Live Activity 상태
│   └── Theme                grayscale 토큰 + elevation(shadow)
├── Void/                    앱
│   ├── Recording/           AudioCapture(마이크→AAC+VAD) · EnergyVAD · RecordingController
│   ├── Processing/          Transcriber(SpeechAnalyzer) · Summarizer(Foundation Models) · WebhookDelivery · ProcessingPipeline
│   ├── Model/               Meeting(SwiftData) · Settings(+Keychain)
│   └── UI/                  HomeView · MeetingDetailView · SettingsView · RecordButton
└── VoidWidgets/             위젯 확장
    ├── RecordControl        컨트롤 센터 / 잠금화면 / Action 버튼
    ├── RecordWidget         홈·잠금화면 위젯
    └── RecordingLiveActivity  잠금화면 배너 + Dynamic Island (정지·계속 버튼)
```

## 흐름

```
[위젯 / 컨트롤 센터 / Action 버튼 / Siri / 앱 버튼]
        │ ToggleRecordingIntent (AudioRecordingIntent → 앱 프로세스에서 실행)
        ▼
RecordingController ──▶ AudioCapture ──(프레임마다 VAD)──▶ SilenceMonitor
        │                    │                                 │ warning → Live Activity "곧 멈춰요"
        │ Live Activity      └─ Recordings/<id>.m4a            │ timeout → stop(.silenceTimeout)
        ▼
ProcessingPipeline: SpeechAnalyzer 받아쓰기 → Foundation Models 요약(map-reduce) → SwiftData 저장 → Webhook(HMAC 서명)
```

## Phase 1 남은 일

- [ ] 첫 빌드 & 컴파일 오류 수정
- [ ] Spike C 체크리스트를 이 앱으로 실기기 검증 (잠금 상태 컨트롤 센터에서 시작, 화면 끈 채 60분)
- [ ] 녹음 중 전화·다른 앱 오디오 등 인터럽션 처리 (`AVAudioSession.interruptionNotification`)
- [ ] EnergyVAD → Silero VAD 교체 (Spike D)
- [ ] 녹음 중 청크 단위 선행 받아쓰기 → 종료 후 대기 시간 단축
- [ ] Webhook 재시도 큐 영속화 (백그라운드 URLSession / BGTask)
- [ ] 앱 아이콘
