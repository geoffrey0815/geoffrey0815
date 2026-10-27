# Release — void

TestFlight·App Store 제출에 필요한 것과, CI가 이미 검증하는 것.

## CI가 매 푸시 검증하는 배포 조건

| 항목 | 기대값 | 검사 위치 |
|---|---|---|
| Release 아카이브 | 성공 (unsigned) | `Release archive (deploy check)` |
| `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` | 한국어 설명 존재 | 같은 잡의 Info.plist 덤프 |
| `UIBackgroundModes` | `audio`, `fetch` | 〃 |
| `BGTaskSchedulerPermittedIdentifiers` | `<bundle id>.webhook-retry` | 〃 |
| `NSSupportsLiveActivities` | `true` | 〃 |
| `ITSAppUsesNonExemptEncryption` | `false` (HTTPS·HMAC만 사용 → 수출 서류 면제) | 〃 |
| `PrivacyInfo.xcprivacy` | 앱·위젯 모두 포함, 추적 없음, 수집 없음, UserDefaults 사유 `CA92.1` | 〃 (`test -f`) |
| 위젯 확장 | `PlugIns/VoidWidgets.appex` 포함 | 〃 |
| VAD 모델 | `silero_vad.onnx` 번들 포함 | 〃 |
| 앱 아이콘 | Assets.car에 AppIcon 렌디션 존재 | 〃 |
| UI 테스트 코드 | Release 바이너리에 `uiTestSeed` 문자열 0개 | 〃 |

## 사람이 해야 하는 것 (Apple 계정 필요)

1. `app/project.yml`의 `VOID_BUNDLE_ID`를 본인 ID로 변경 → `xcodegen`
2. Xcode › Signing & Capabilities: Void, VoidWidgets 두 타깃 Team 선택 (App Group·Push 등 추가 capability 없음)
3. App Store Connect에서 앱 생성 (번들 ID 동일)
4. Xcode › Product › Archive → Distribute App → TestFlight
5. 실기기 체크리스트 (`spikes/C-background-recording/README.md`) 통과 후 심사 제출

## App Store Connect 입력값 (초안)

- **이름:** void — 로컬 회의록
- **부제:** 누르면 듣고, 끝나면 정리해서 보내요
- **카테고리:** 생산성 (보조: 비즈니스)
- **키워드:** 회의록,녹음,받아쓰기,요약,전사,webhook,오프라인,프라이버시,AI,메모
- **설명:**
  > 위젯이나 제어 센터에서 한 번 누르면 녹음이 시작됩니다. 회의가 끝나 조용해지면 알아서 멈추고, 받아쓰기·요약·결정사항·할 일을 정리해 원하는 주소(webhook)로 보냅니다.
  >
  > 모든 처리는 iPhone 안에서 이루어집니다. 녹음, 받아쓰기, 요약은 기기 밖으로 나가지 않으며, 외부로 나가는 것은 직접 등록한 webhook뿐입니다.
  >
  > • 위젯 · 제어 센터 · 잠금화면 · Action 버튼에서 1탭 녹음
  > • 잠금화면·Dynamic Island에 녹음 상태와 정지 버튼
  > • 말소리가 없으면 자동 종료 (2~30분 설정)
  > • 온디바이스 받아쓰기와 요약, 회의에 대해 질문하기
  > • 서명된 webhook으로 Notion·Slack·자동화 도구와 연결
  > • 오디오 보관 기간 설정, 용어집
- **개인정보 처리방침 URL:** 필요 (내용: 수집하는 데이터 없음, 사용자가 지정한 webhook으로만 전송)
- **App Privacy (영양 라벨):** *Data Not Collected*
  - 근거: 분석·광고·크래시 SDK 없음. 네트워크 사용처는 사용자가 등록한 webhook 하나(`WebhookDelivery`)뿐이며 개발자가 받지 않음.
- **심사 메모:** Apple Intelligence 지원 기기에서 요약이 동작합니다. webhook은 선택 기능이며, 설정 › Webhook › 테스트 전송으로 확인할 수 있습니다.

## 요구 기기

- iOS 26 이상, 요약·질문하기는 Apple Intelligence 지원 기기 (iPhone 15 Pro 이상)
- 받아쓰기 언어 모델은 언어별로 처음 한 번 Apple에서 내려받음 (이후 오프라인)
