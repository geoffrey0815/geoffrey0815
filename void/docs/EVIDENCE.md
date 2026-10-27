# Evidence log — void

각 단계에서 **"잘 작동하는가 · 디자인에 문제 없는가 · 깨진 곳은 없는가 · 배포 가능한가"** 를 무엇으로 확인했는지 기록한다.
모든 항목은 재현 가능한 출처(CI 실행, 테스트 이름, 스크린샷 파일)를 가진다.

## 검증 수단

| 질문 | 수단 | 어디서 |
|---|---|---|
| 핵심 로직이 맞는가 | VoidCore 단위 테스트 (Swift Testing) | CI `VoidCore tests` |
| 앱 로직이 맞는가 | iOS 시뮬레이터 테스트 — 가짜 온디바이스 모델 + 스텁 네트워크로 파이프라인 전체 실행 | CI `iOS tests and screenshots` → `VoidTests` |
| 음성 감지가 맞는가 | 번들 Silero 모델로 음성 합성 / 무음 / 소음 판별 | `VoidTests/SileroVADTests` |
| 화면이 깨지지 않는가 | 시드 데이터로 모든 화면을 라이트·다크 렌더링, 스크린샷 보관 | `VoidUITests` → artifact `evidence-screenshots`, 사본은 `docs/evidence/` |
| 배포 가능한가 | Release 아카이브 + Info.plist·개인정보 매니페스트·위젯·모델·아이콘 검사 | CI `Release archive (deploy check)` → artifact `evidence-release-report` |
| 실제 오디오에서 동작하는가 | 실제 52분 녹음으로 전사·무음 로직 재현 | `spikes/A-stt-bench/BASELINE.md`, `spikes/D-silence-autostop/RESULT.md` |

## 아직 증거가 없는 것 (실기기·Mac 필요)

- 잠금 상태 제어 센터에서 녹음 시작, 화면 끈 채 60분 (Spike C)
- SpeechAnalyzer 한국어 정확도·속도, Foundation Models 요약 품질 (Spike A·B)
- 실제 마이크 입력 → 실시간 받아쓰기 → 요약 전 과정

## 기록

### E1 · Phase 0 — 실제 녹음으로 파이프라인 설계 검증 (2026-10-27)
- **무엇을:** 52분 강연 녹음(영어, 원거리)을 Whisper turbo + Silero VAD로 전사.
- **결과:** VAD 구간을 ≤25 s 창으로 병합하자 RTF 0.41 → 0.18, 조각난 환각 문장 제거. → `VoidCore/SpeechWindowing` 채택.
- **증거:** `spikes/A-stt-bench/BASELINE.md` (구간별 수치·예문).

### E2 · 무음 자동 종료 임계값 (2026-10-27)
- **무엇을:** 앱의 Silero + `SilenceMonitor` 로직을 Python으로 재현해 같은 녹음에 실행.
- **결과:** 가장 긴 자연 무음 61.4 s. 1분 설정은 45:30에 오종료, 2·3분은 끝까지 녹음 → 최소 2분, 기본 3분.
- **증거:** `spikes/D-silence-autostop/RESULT.md`.

### E3 · 첫 컴파일 · 단위 테스트 (PR #1, 2026-10-27)
- **무엇을:** Linux에서 작성한 코드를 macOS 26 CI에서 처음 빌드.
- **결과:** VoidCore 테스트 20개 → 리뷰 반영 후 24개 통과, 앱·위젯 unsigned 빌드 성공, 스파이크 벤치 빌드 성공. 경고는 SwiftData `#Predicate` 매크로의 Sendable 경고뿐(프레임워크 측).
- **증거:** Actions run 40532831903 (첫 빌드), 40534836432 (PR #1 최종 head 9de234a).
- **리뷰:** Codex·Sourcery 27건 전부 답변 (수정/이미 수정됨/문서 정정).

### E4 · 시뮬레이터 테스트 + 화면 검수 (a55a7aa, CI run 40538367850)
- **결과:** 26개 중 25 통과, 1 실패. VoidCore·앱 빌드·스파이크·Release 아카이브 모두 통과.
  - 실패 `testClientErrorIsNotRetried` → **실제 버그:** 4xx로 거부·재시도 소진된 전송에 60 s 리스(`nextDeliveryAt`)가 남아 "재시도 예정"처럼 보임 → 수정(78bb4f7).
  - Silero: 합성 음성은 음성으로, 무음·잡음은 아님으로 판별 (`SileroVADTests` 4개 통과).
- **배포 점검에서 발견:** `CFBundleShortVersionString`이 `0.1.0`이 아닌 `1.0` (XcodeGen 기본값) → 앱·위젯 모두 빌드 설정에 고정하고, CI가 앱/위젯 버전 일치를 검사(42712ec). 위젯 버전이 앱과 다르면 App Store 검증에서 거절된다.
- **화면 검수 (직접 확인):** [홈·상세](evidence/a55a7aa/screens-home-detail.png) · [상태들](evidence/a55a7aa/screens-states.png) · [설정](evidence/a55a7aa/screens-settings.png) · [Live Activity·위젯](evidence/a55a7aa/live-activity-widget.png)
  - 라이트/다크 모두 깨짐·겹침 없음. grayscale + 그림자 원칙 유지. 마이크 없는 시뮬레이터에서 녹음 버튼을 눌러도 크래시 없음.
  - 발견한 문제 6개 → 수정:
    1. 제목 없는 회의가 목록·상세에서 날짜를 두 번 표시 → 상태별 제목(“정리 중인 회의”, “요약하지 못한 회의”)
    2. 마이크 권한 알림이 다음 테스트 스크린샷까지 남음 → SpringBoard에서 응답
    3. 삭제가 빨간색(유일한 색) + 확인 없이 즉시 삭제 → 회색 + 확인 대화상자
    4. 시스템 강조색(파랑·초록)이 토글·대화상자에 나올 수 있음 → 앱 전체 `tint(Theme.ink)`
    5. Live Activity의 정지·계속이 버튼처럼 보이지 않음 → 캡슐 버튼(정지는 채움)
    6. (1과 같은 원인) 실패 상세 화면 제목이 날짜

### E5 · 수정 확인 + 접근성 텍스트 (597cbc0, CI run 40592460948)
- **결과:** 5개 잡 전부 통과. 시뮬레이터 테스트 **27/27 통과** (E4의 실패 포함).
- **배포 점검:** 앱·위젯 버전 `0.1.0 (1)` 일치, 아이콘 6개 렌디션, Release 바이너리에 테스트 코드 0.
- **E4 수정 6개 화면으로 확인:** 상태별 제목, 회색 삭제 + 확인 대화상자, 권한 알림 잔상 없음, 질문하기 흐름(질문→답변) 라이트·다크 정상. → [화면](evidence/597cbc0/screens-fixed.png)
- **새로 확인:** 시뮬레이터에서 녹음 버튼 → 권한 허용 → 실제로 녹음 시작(0:03, "녹음 중인 회의")까지 동작.
- **새로 발견 (가장 큰 글자 크기):** [화면](evidence/597cbc0/screens-large-text.png)
  7. 목록 행에서 상태 라벨이 제목을 "정리 중인..."으로 잘라 먹음
  8. 상세 머리글의 날짜·시간·상태가 한 줄에 몰려 날짜가 단어 단위로 세로로 깨짐
  → 둘 다 `ViewThatFits`로 한 줄에 안 들어가면 세로로 쌓도록 수정.

### E6 · 최대 글자 크기 수정 확인 (81fdd2d, CI run 40593963525)
- **결과:** 5개 잡 전부 통과, 시뮬레이터 테스트 27/27.
- **화면:** [최대 글자 크기 vs 기본 크기](evidence/81fdd2d/large-text-fixed.png) — 목록 제목이 잘리지 않고 상태가 아래로 내려감, 상세 날짜가 두 줄로 읽힘. 기본 크기 레이아웃은 그대로.
- **남은 개선 여지(사소):** 최대 크기에서 상세의 날짜와 시간이 나란히 두 줄로 감김. 읽는 데 문제 없어 그대로 둠.
