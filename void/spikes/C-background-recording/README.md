# Spike C — 앱 밖에서 시작 + 화면 꺼진 채 60분 녹음

**질문:** 앱을 열지 않고 1탭으로 녹음을 시작하고, 화면을 끈 채 60분 동안 녹음이 끊기지 않는가?

## 만들 것 (최소 Xcode 프로젝트)

1. `StartRecordingIntent: AudioRecordingIntent` (App Intents) — 녹음 시작
2. 이 인텐트를 실행하는 진입점 3개
   - `ControlWidget` (컨트롤 센터 / 잠금화면 / Action 버튼)
   - 홈 화면 위젯 버튼 (`Button(intent:)`)
   - Shortcuts / Siri
3. 녹음 중 `Live Activity` (경과 시간 + 정지 버튼, grayscale)
4. `Info.plist`: `UIBackgroundModes = audio`, `NSMicrophoneUsageDescription`
5. `AVAudioEngine` 입력 탭 → 30초 단위로 `.caf` 파일에 나눠 저장

> iOS는 백그라운드에서 녹음을 *시작*하는 것을 제한한다. `AudioRecordingIntent`를 따르면서 Live Activity를 띄우는 것이 공식 경로다.
> 이 스파이크의 핵심은 **이 경로가 컨트롤 센터에서 실제로 동작하는지** 확인하는 것이다.

## 체크리스트 (실기기에서)

- [ ] 잠금 상태에서 컨트롤 센터 버튼 → 녹음 시작 (앱 화면이 뜨지 않음)
- [ ] 위젯 버튼 → 녹음 시작
- [ ] Action 버튼 → 녹음 시작
- [ ] 화면 끄고 60분 → 파일 누락 없음
- [ ] 녹음 중 전화 수신 / 다른 앱 오디오 재생 → 중단과 재개 처리
- [ ] 60분 동안 배터리 소모 %
- [ ] 녹음 중 청크 단위 STT를 백그라운드에서 돌릴 수 있는가 (가능하면 종료 후 대기 시간 대폭 감소)
