# Spike A — 한국어 온디바이스 전사 비교

**질문:** WhisperKit과 Apple SpeechAnalyzer 중 무엇이 한국어 회의에 더 적합한가?

## 준비

- macOS 26 + Xcode 26 (Apple Silicon Mac)
- 실제 회의 녹음 3개 (10분 / 30분 / 60분 권장, 여러 사람·잡음 섞인 것)
- 그중 최소 1개는 정답 전사본(`reference.txt`) — 10분짜리를 손으로 다듬으면 충분

## 실행

```bash
cd spikes/A-stt-bench
swift run -c release stt-bench ~/meetings/m1.m4a ~/meetings/m1.ref.txt all
# 정답이 없으면 두 번째 인자를 - 로
swift run -c release stt-bench ~/meetings/m2.m4a - all
```

출력 예: `whisperkit  time 95.2s  RTF 0.053  CER 8.4%`
- **RTF** (처리시간 ÷ 오디오 길이): 0.1이면 60분 회의를 6분에 처리
- **CER**: 낮을수록 좋음. 띄어쓰기·문장부호는 무시

## 판단 기준

| 항목 | 합격선 |
|---|---|
| CER | ≤ 12% |
| Mac RTF | ≤ 0.1 (iPhone은 대략 2~4배 느리다고 가정, 실기기 확인 필요) |
| 오프라인 | 모델 설치 후 Wi-Fi 끄고 재실행해 동작 확인 |
| 앱 용량 | WhisperKit은 모델(~600MB+) 별도 다운로드 필요 / SpeechAnalyzer는 OS 자산 |

CER 차이가 3%p 이내면 **SpeechAnalyzer** 우선 (앱 용량·배터리·유지보수 유리).

## 주의

이 코드는 Linux 환경에서 작성되어 **아직 컴파일해 보지 않았다.** 특히 SpeechAnalyzer API는 Xcode에서 시그니처를 확인할 것.

결과는 `RESULT.md`에 기록 → ADR-0002 작성.
