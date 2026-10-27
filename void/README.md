# void

> 누르면 듣고, 멈추면 정리해서 보내는 회의록. 아무것도 기기 밖으로 나가지 않는다.

간단하고 AI-native한, 완전 로컬 회의록 앱 (가칭).

## 핵심 원칙

| # | 원칙 | 한 줄 정의 |
|---|------|-----------|
| 1 | **Zero-friction 시작** | 위젯 / 알림바(컨트롤 센터) / 잠금화면에서 1탭으로 녹음 시작 |
| 2 | **AI-native** | 전사 → 요약 → 액션아이템이 기본 결과물. 원문은 부가 정보 |
| 3 | **Minimal** | grayscale + shadow만. 색은 쓰지 않는다 |
| 4 | **Webhook 출력** | 녹음 종료 시 결과 JSON을 사용자가 지정한 URL로 POST |
| 5 | **무음 자동 종료** | 무음이 m분 이어지면 자동으로 멈추고 처리 시작 |
| 6 | **완전 로컬** | 전사·요약 모두 온디바이스. 외부로 나가는 것은 사용자가 지정한 webhook뿐 |

## 폴더 구조

```
void/
├── README.md          ← 지금 이 파일
├── docs/
│   ├── PRD.md         ← 제품 요구사항 (무엇을 / 왜)
│   ├── ARCHITECTURE.md← 기술 구조 (어떻게)
│   ├── ROADMAP.md     ← 단계별 계획
│   └── adr/           ← 기술 결정 기록 (Architecture Decision Records)
├── spikes/            ← 위험 검증용 일회성 실험 (A 전사 · B 요약 · C 백그라운드 녹음 · D 무음 종료)
└── app/
    └── VoidCore/      ← 플랫폼 독립 로직 Swift Package (무음 판정, webhook, 청크 분할)
```

## 지금 어디까지?

**Phase 0 — 위험 검증.** 플랫폼은 iOS로 확정 ([ADR-0001](docs/adr/0001-primary-platform.md)). [`docs/ROADMAP.md`](docs/ROADMAP.md) 참고.

## 시작하기 (Mac)

```bash
cd app/VoidCore && swift test        # 핵심 로직 테스트
cd spikes/A-stt-bench && swift run -c release stt-bench <회의.m4a> <정답.txt>
```

요구사항: macOS 26 + Xcode 26, Apple Silicon. 스파이크별 방법은 각 폴더의 README 참고.
