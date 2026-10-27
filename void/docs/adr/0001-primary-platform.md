# ADR-0001: 1차 타깃 플랫폼

- 상태: **Accepted** (2026-10-27)
- 날짜: 2026-10-27

## 맥락

"위젯이나 알림바에서 시작" + "완전 로컬 AI" 두 요구가 플랫폼 선택을 좌우한다.

## 선택지

| | iOS | Android | macOS |
|---|---|---|---|
| 1탭 시작 | 위젯·컨트롤 센터·Action 버튼·Live Activity 모두 지원 | Quick Settings Tile이 가장 강력 | 메뉴바 |
| 로컬 LLM | Foundation Models 프레임워크 내장 (모델 다운로드 불필요) | Gemini Nano는 일부 기기만 | 가장 여유로움 |
| 로컬 STT | WhisperKit / SpeechAnalyzer | whisper.cpp | 가장 빠름 |
| 리스크 | 백그라운드 추론 제약 | 기기 파편화 | 모바일 회의엔 부적합 |

## 제안

**iOS 우선 (Swift + SwiftUI)**, 같은 코어를 macOS 메뉴바 앱으로 확장.
OS 내장 LLM이 있어 "완전 로컬 + 앱 용량 작음"을 동시에 만족하는 유일한 선택지.

## 결정

**iOS 26+ / Swift 6 / SwiftUI**로 간다.

- 로컬 요약: Apple Foundation Models (Apple Intelligence 지원 기기 필요 — iPhone 15 Pro 이상)
- 로컬 전사: WhisperKit vs SpeechAnalyzer는 Spike A 결과로 ADR-0002에서 결정
- 공통 로직은 `app/VoidCore` Swift Package로 분리해 macOS 메뉴바 앱 확장에 재사용
