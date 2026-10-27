# Spike A — CPU 기준선 (Mac/iPhone 측정 전 참고치)

WhisperKit·SpeechAnalyzer 비교 전에, 같은 Whisper 모델을 일반 CPU에서 돌려 **파이프라인 설계**를 검증한 결과.

- 녹음: 52분 강연 + Q&A, 영어(비원어민 화자), 강의실 원거리 녹음
- 엔진: Whisper large-v3-turbo int8 (sherpa-onnx), Linux x86 CPU 4코어
- VAD: Silero VAD
- 정답 전사본 없음 → CER 미측정. 품질은 정성 비교

## 결과

| 방식 | 디코딩 단위 | 처리 시간 | RTF | 단어 수 | 품질 |
|---|---|---|---|---|---|
| ① VAD 구간별 | 395개 (중앙값 2.8 s) | 1,260 s | 0.41 | 4,075 | 조각난 문장, 환각 다수 |
| ② ① + 필터 | 337개 | — | — | 4,359 | 환각 58개 제거 (`Thank you.` ×36 등) |
| **③ ≤25 s 창으로 병합** | **159개** | **553 s** | **0.18** | 4,352 | **문맥 유지, 가장 읽기 좋음** |

예시 (같은 구간):
- ①: `secret sound mode.` / `$50,000.` / `on` / `Good.`
- ③: `I want to be a machine learning or data scientist job. ... If you are only focusing on the data scientist job ... very difficult for you to get so-called a head of DNA`

## 결론 → 앱 설계에 반영

1. **VAD 구간을 그대로 STT에 넣지 않는다.** ≤25 s 창으로 병합 → `VoidCore/SpeechWindowing` 구현.
2. Whisper 계열은 무음·잡음에서 `Thank you.` 같은 환각을 낸다 → VAD로 무음 제거 + 짧은 상투구 필터 필요.
3. CPU 4코어에서도 RTF 0.18 → Apple Neural Engine(WhisperKit)에서는 60분 회의를 수 분 내 처리할 수 있을 것으로 기대. **실기기 측정으로 확인 필요.**
4. 원거리·비원어민 음성은 여전히 오인식이 많다 (`DNA`↔`D&A`, `GPS`↔`GPA`). 요약 단계에서 문맥 교정 지시가 필요하고, 사용자 용어집(커스텀 어휘) 기능 후보.
