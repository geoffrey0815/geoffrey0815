# Simulator tests — 597cbc0

- Simulator: iPhone 17 Pro
- Passed: 27
- Failed: 0
- Result: TEST SUCCEEDED

```
'-[VoidTests.PipelineTests testClientErrorIsNotRetried]' passed (0.092 seconds).
'-[VoidTests.PipelineTests testDefaultRetentionKeepsAudio]' passed (0.009 seconds).
'-[VoidTests.PipelineTests testDeleteRemovesMeetingAndRecording]' passed (0.010 seconds).
'-[VoidTests.PipelineTests testGlossaryParsing]' passed (0.008 seconds).
'-[VoidTests.PipelineTests testImmediateRetentionDeletesAudioAfterProcessing]' passed (0.018 seconds).
'-[VoidTests.PipelineTests testLiveTranscriptSkipsFileTranscription]' passed (0.014 seconds).
'-[VoidTests.PipelineTests testMissingAudioFileClearsStaleReference]' passed (0.039 seconds).
'-[VoidTests.PipelineTests testPlainHTTPWebhookIsNeverUsed]' passed (0.016 seconds).
'-[VoidTests.PipelineTests testPlainTextHasSummaryDecisionsAndTasks]' passed (0.248 seconds).
'-[VoidTests.PipelineTests testProcessTranscribesSummarizesAndDeliversSignedWebhook]' passed (0.017 seconds).
'-[VoidTests.PipelineTests testPurgeDeletesOnlyExpiredAudioOfProcessedMeetings]' passed (0.014 seconds).
'-[VoidTests.PipelineTests testRetentionCountsFromProcessingNotRecording]' passed (0.012 seconds).
'-[VoidTests.PipelineTests testServerErrorSchedulesPersistedRetry]' passed (0.024 seconds).
'-[VoidTests.PipelineTests testSummaryFailureMarksFailedAndReprocessRecovers]' passed (0.026 seconds).
'-[VoidTests.PipelineTests testTranscriptIsIncludedWhenOptedIn]' passed (0.017 seconds).
'-[VoidTests.PipelineTests testZeroRetentionClearsAlreadyProcessedAudio]' passed (0.016 seconds).
'-[VoidTests.SileroVADTests testBundledModelLoads]' passed (0.207 seconds).
'-[VoidTests.SileroVADTests testSilenceIsNotSpeech]' passed (0.066 seconds).
'-[VoidTests.SileroVADTests testSteadyNoiseIsMostlyNotSpeech]' passed (0.156 seconds).
'-[VoidTests.SileroVADTests testSynthesizedSpeechIsSpeech]' passed (2.521 seconds).
'-[VoidTests.WidgetRenderTests testLiveActivityAndWidgetRender]' passed (1.158 seconds).
'-[VoidUITests.ScreenshotTests testAccessibilityTextSize]' passed (41.766 seconds).
'-[VoidUITests.ScreenshotTests testDeleteFromContextMenu]' passed (15.595 seconds).
'-[VoidUITests.ScreenshotTests testEmptyState]' passed (6.519 seconds).
'-[VoidUITests.ScreenshotTests testRecordButtonFailsGracefullyWithoutMicrophone]' passed (21.800 seconds).
'-[VoidUITests.ScreenshotTests testScreensDark]' passed (101.147 seconds).
'-[VoidUITests.ScreenshotTests testScreensLight]' passed (26.733 seconds).
```
