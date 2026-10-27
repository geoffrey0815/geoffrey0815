# Roadmap — void

## Phase 0 · 결정 & 위험 검증

UI보다 먼저, **"이게 로컬에서 정말 되는가"** 를 확인한다.

- [x] ADR-0001: 1차 플랫폼 → iOS
- [x] VoidCore: 무음 자동 종료 · webhook 페이로드/서명/재시도 · 청크 분할 · 음성 창 병합 (CI에서 테스트)
- [~] Spike A — 전사: CPU 기준선 완료 (`spikes/A-stt-bench/BASELINE.md`). **WhisperKit vs SpeechAnalyzer 비교는 Mac에서 실행 필요** → ADR-0002
- [ ] Spike B — 온디바이스 요약 품질: **Apple Intelligence Mac에서 실행 필요** (벤치 코드는 CI에서 빌드됨)
- [ ] Spike C — 컨트롤 센터에서 시작 + 화면 끈 채 60분: **실기기 필요**
- [x] Spike D — 무음 자동 종료: 실제 52분 녹음으로 앱 로직 재현, 기본 3분 / 최소 2분 확정

## Phase 1 · MVP ← 지금

F1~F6 (P0). 화면은 홈 / 상세 / 설정 3개. 본인이 매일 쓰는 수준까지.

- [x] 앱 뼈대: 위젯 · 컨트롤 센터 · Live Activity · 녹음 · 무음 종료 · 실시간 받아쓰기 · 요약 · webhook (CI 빌드 통과)
- [x] 안정성: 인터럽션 처리, 크래시 후 복구, webhook 재시도 영속화, 다시 처리
- [x] F8 오디오 보관 기간 (바로 삭제 / 7일 / 30일 / 계속)
- [x] webhook 테스트 전송
- [ ] 실기기 첫 실행 → Spike C 체크리스트
- [ ] 본인이 1주일 실제 회의에 사용 → 불편 목록

## Phase 2 · 다듬기

TestFlight 베타, 요약 템플릿(회의/강연), 용어집(고유명사 교정), 디자인 시스템 정리.

## Phase 3 · AI-native 확장

회의에 질문하기 (F9), 화자 구분, macOS 메뉴바 앱.
