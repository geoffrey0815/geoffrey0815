# Architecture — void (초안)

플랫폼 미확정. 아래는 **iOS 우선**을 가정한 권장안이며, 확정은 `adr/0001`에서 한다.

## 파이프라인

```
[Trigger]            [Capture]              [Process — 전부 온디바이스]            [Deliver]
Widget  ─┐
Control  ─┼─▶ AudioEngine ─▶ VAD ──(무음 m분)──▶ stop
Lock     ─┘        │          │
                   ▼          ▼
               chunk 파일   speech segments ─▶ STT ─▶ transcript ─▶ LLM ─▶ JSON ─▶ Webhook (HMAC, 재시도 큐)
```

## 컴포넌트별 후보

| 영역 | iOS (권장) | Android | macOS |
|------|-----------|---------|-------|
| 1탭 시작 | WidgetKit + ControlWidget(컨트롤 센터) + App Intents, Action 버튼 | Quick Settings Tile + Glance 위젯 | 메뉴바 앱 + 전역 단축키 |
| 녹음 상태 | Live Activity / Dynamic Island | Foreground Service 알림 | 메뉴바 아이콘 |
| VAD | Silero VAD (Core ML) | Silero VAD (ONNX) | Silero VAD |
| STT | WhisperKit vs Apple SpeechAnalyzer — **스파이크로 비교** | whisper.cpp | WhisperKit / whisper.cpp |
| 요약 LLM | Apple Foundation Models framework | Gemini Nano (ML Kit GenAI) 또는 llama.cpp | Foundation Models / MLX |
| 저장 | SwiftData + 파일 보호(Complete) | Room + EncryptedFile | SwiftData |
| 전송 | URLSession background + 재시도 큐 | WorkManager | URLSession |

## 핵심 설계 포인트

1. **청크 단위 처리**: 녹음 중 30초~1분 단위로 STT를 미리 돌려, 종료 후 대기 시간을 줄인다.
2. **긴 회의 요약**: 온디바이스 LLM은 컨텍스트가 짧다 → 구간별 요약 후 합치는 map-reduce.
3. **구조화 출력**: LLM 출력은 스키마(JSON)로 강제 (Foundation Models의 `@Generable` 등).
4. **무음 판정**: 볼륨 임계값이 아니라 VAD의 "음성 없음" 지속 시간으로 판단. 종료 30초 전 알림으로 오탐 방지.
5. **백그라운드 제약**: iOS에서 녹음은 백그라운드 오디오로 유지되지만, 무거운 추론은 앱이 포그라운드이거나 BGProcessingTask일 때 안정적. → 스파이크 대상.
