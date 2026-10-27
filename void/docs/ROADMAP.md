# Roadmap — void

## Phase 0 · 결정 & 위험 검증 (1~2주) ← 지금

UI보다 먼저, **"이게 로컬에서 정말 되는가"** 를 확인한다.

- [x] ADR-0001: 1차 플랫폼 → iOS
- [x] VoidCore: 무음 자동 종료 상태머신, webhook 페이로드·서명·재시도 정책 (단위 테스트 작성됨 — Mac에서 `swift test`로 첫 실행 필요)
- [ ] Spike A — 한국어 STT 품질/속도: WhisperKit vs SpeechAnalyzer, 실제 회의 녹음 3개로 비교 (CER, 60분당 처리 시간, 배터리)
- [ ] Spike B — 온디바이스 요약 품질: 한국어 회의 전사본 → 요약/결정/액션아이템 JSON. 60분 분량 map-reduce
- [ ] Spike C — 백그라운드 녹음 + 컨트롤 센터/위젯에서 시작, 화면 꺼진 상태 60분 유지
- [ ] Spike D — VAD 기반 무음 자동 종료 (오탐 테스트: 긴 침묵이 있는 회의, 키보드 소리, 에어컨 소음)

**종료 조건:** 4개 스파이크 결과를 `spikes/*/RESULT.md`로 기록하고 기술 스택 확정.

## Phase 1 · MVP (3~4주)

F1~F6 (P0). 화면은 홈 / 상세 / 설정 3개. 본인이 매일 쓰는 수준까지.

## Phase 2 · 다듬기

P1 기능, 디자인 시스템(grayscale 토큰 + elevation 단계) 정리, TestFlight 베타.

## Phase 3 · AI-native 확장

회의에 질문하기, 요약 템플릿, 화자 구분.
