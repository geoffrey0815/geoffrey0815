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
