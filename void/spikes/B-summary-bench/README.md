# Spike B — 온디바이스 요약 품질

**질문:** Apple Foundation Models(약 3B, 컨텍스트 4,096 토큰)로 60분짜리 한국어 회의를 쓸 만하게 요약할 수 있는가?

## 실행

Apple Intelligence가 켜진 Mac (macOS 26)에서:

```bash
cd spikes/B-summary-bench
# Spike A에서 나온 전사본을 그대로 입력
swift run -c release summary-bench ~/meetings/m1.speechanalyzer.txt
# 청크 크기 실험
swift run -c release summary-bench ~/meetings/m1.speechanalyzer.txt 1000
swift run -c release summary-bench ~/meetings/m1.speechanalyzer.txt 2200
```

출력은 실제 webhook 페이로드(`MeetingResult`)와 같은 형식의 JSON이다.

## 평가 (회의 참석자 본인이 채점)

| 항목 | 방법 |
|---|---|
| 결정사항 재현율 | 실제 결정 중 몇 개를 잡았나 |
| 환각 | 회의에 없던 내용이 하나라도 있으면 실패 |
| 액션아이템 담당자 정확도 | 맞은 수 / 전체 |
| 처리 시간 | 60분 회의 기준 total 초 |
| 청크 크기 | 1000 / 1500 / 2200 중 컨텍스트 초과 오류 없이 가장 좋은 것 |

**합격선:** 환각 0건, 결정사항 재현율 ≥ 80%.

불합격이면 → 대안: MLX + 더 큰 로컬 모델(예: Qwen/Gemma 계열 4bit)을 모델 다운로드 옵션으로 제공. 이 경우 앱 용량·발열을 다시 평가.

## 주의

아직 컴파일해 보지 않은 코드다 (Linux 환경에서 작성). `@Generable`/`LanguageModelSession` 시그니처는 Xcode에서 확인할 것.
