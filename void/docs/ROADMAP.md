# Roadmap — void

## Phase 0 · 결정 & 위험 검증

UI보다 먼저, **"이게 로컬에서 정말 되는가"** 를 확인한다.

- [x] ADR-0001: 1차 플랫폼 → iOS
- [x] VoidCore: 무음 자동 종료 · webhook 페이로드/서명/재시도 · 청크 분할 · 음성 창 병합 (CI에서 테스트)
- [~] Spike A — 전사: CPU 기준선 완료 (`spikes/A-stt-bench/BASELINE.md`). **WhisperKit vs SpeechAnalyzer 비교는 Mac에서 실행 필요** → ADR-0002
- [ ] Spike B — 온디바이스 요약 품질: **Apple Intelligence Mac에서 실행 필요** (벤치 코드는 CI에서 빌드됨)
- [ ] Spike C — 컨트롤 센터에서 시작 + 화면 끈 채 60분: **실기기 필요**
- [x] Spike D — 무음 자동 종료: 실제 52분 녹음으로 앱 로직 재현, 기본 3분 / 최소 2분 확정

## Phase 1 · MVP — 완료 (실기기 검증만 남음)

F1~F9 구현, 매 푸시 CI 검증. 증거: [`EVIDENCE.md`](EVIDENCE.md).

- [x] 1탭 시작: 위젯 · 제어 센터 · 잠금화면 · Action 버튼 · Siri (`AudioRecordingIntent`)
- [x] Live Activity / Dynamic Island: 경과 시간, 정지, 무음 경고 + 계속
- [x] 녹음: AAC, Silero VAD(번들), 인터럽션·라우트 변경 처리, 크래시 복구
- [x] 무음 자동 종료 (기본 3분, 최소 2분 — 실제 녹음 데이터로 결정)
- [x] 실시간 받아쓰기(SpeechAnalyzer) + 파일 받아쓰기 대체, 용어집
- [x] 온디바이스 요약(Foundation Models, 계층적 map-reduce)
- [x] 서명된 webhook(HTTPS 전용, 재시도 영속화, 테스트 전송)
- [x] 목록·상세·삭제·공유/복사·다시 처리·빈 화면 (F7)
- [x] 오디오 보관 기간 (F8)
- [x] 회의에 질문하기 (F9)
- [x] 배포 준비: 개인정보 매니페스트, 버전 일치, Release 아카이브 검사, App Store 문구 ([`RELEASE.md`](RELEASE.md))
- [x] 디자인 검수: 라이트·다크·최대 글자 크기 스크린샷 리뷰, 발견 8건 수정
- [ ] **실기기:** Spike C 체크리스트 (잠금 상태 제어 센터 시작, 화면 끈 채 60분, 실제 마이크 → 요약 → webhook)
- [ ] **Mac:** Spike A(받아쓰기 엔진 비교 → ADR-0002) · Spike B(요약 품질)
- [ ] 본인이 1주일 실제 회의에 사용 → 불편 목록

## Phase 2 · 다듬기

TestFlight 베타, 요약 템플릿(회의/강연), 디자인 시스템 정리.

## Phase 3 · 확장

화자 구분, macOS 메뉴바 앱(VoidCore 재사용).
