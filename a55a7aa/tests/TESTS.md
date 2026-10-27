# Simulator tests — a55a7aa

- Simulator: iPhone 17 Pro
- Passed: 25
- Failed: 1
- Result: 

```
/Users/runner/work/geoffrey0815/geoffrey0815/void/app/VoidTests/PipelineTests.swift:130: error: -[VoidTests.PipelineTests testClientErrorIsNotRetried] : XCTAssertNil failed: "2026-10-27 16:22:15 +0000"
'-[VoidTests.PipelineTests testClientErrorIsNotRetried]' failed (0.858 seconds).
'-[VoidTests.PipelineTests testDefaultRetentionKeepsAudio]' passed (0.087 seconds).
'-[VoidTests.PipelineTests testDeleteRemovesMeetingAndRecording]' passed (0.015 seconds).
'-[VoidTests.PipelineTests testGlossaryParsing]' passed (0.017 seconds).
'-[VoidTests.PipelineTests testImmediateRetentionDeletesAudioAfterProcessing]' passed (0.026 seconds).
'-[VoidTests.PipelineTests testLiveTranscriptSkipsFileTranscription]' passed (0.051 seconds).
'-[VoidTests.PipelineTests testMissingAudioFileClearsStaleReference]' passed (0.017 seconds).
'-[VoidTests.PipelineTests testPlainHTTPWebhookIsNeverUsed]' passed (0.028 seconds).
'-[VoidTests.PipelineTests testPlainTextHasSummaryDecisionsAndTasks]' passed (0.033 seconds).
'-[VoidTests.PipelineTests testProcessTranscribesSummarizesAndDeliversSignedWebhook]' passed (0.055 seconds).
'-[VoidTests.PipelineTests testPurgeDeletesOnlyExpiredAudioOfProcessedMeetings]' passed (0.025 seconds).
'-[VoidTests.PipelineTests testRetentionCountsFromProcessingNotRecording]' passed (0.019 seconds).
'-[VoidTests.PipelineTests testServerErrorSchedulesPersistedRetry]' passed (0.034 seconds).
'-[VoidTests.PipelineTests testSummaryFailureMarksFailedAndReprocessRecovers]' passed (0.052 seconds).
'-[VoidTests.PipelineTests testTranscriptIsIncludedWhenOptedIn]' passed (0.039 seconds).
'-[VoidTests.PipelineTests testZeroRetentionClearsAlreadyProcessedAudio]' passed (0.030 seconds).
'-[VoidTests.SileroVADTests testBundledModelLoads]' passed (0.249 seconds).
'-[VoidTests.SileroVADTests testSilenceIsNotSpeech]' passed (0.087 seconds).
'-[VoidTests.SileroVADTests testSteadyNoiseIsMostlyNotSpeech]' passed (0.250 seconds).
'-[VoidTests.SileroVADTests testSynthesizedSpeechIsSpeech]' passed (72.490 seconds).
'-[VoidTests.WidgetRenderTests testLiveActivityAndWidgetRender]' passed (7.398 seconds).
'-[VoidUITests.ScreenshotTests testDeleteFromContextMenu]' passed (65.390 seconds).
'-[VoidUITests.ScreenshotTests testEmptyState]' passed (14.711 seconds).
'-[VoidUITests.ScreenshotTests testRecordButtonFailsGracefullyWithoutMicrophone]' passed (19.723 seconds).
'-[VoidUITests.ScreenshotTests testScreensDark]' passed (40.353 seconds).
'-[VoidUITests.ScreenshotTests testScreensLight]' passed (34.825 seconds).
```
