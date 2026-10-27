# Simulator tests — 81fdd2d

- Simulator: iPhone 17 Pro
- Passed: 27
- Failed: 0
- Result: TEST SUCCEEDED

```
'-[VoidTests.PipelineTests testClientErrorIsNotRetried]' passed (0.134 seconds).
'-[VoidTests.PipelineTests testDefaultRetentionKeepsAudio]' passed (0.018 seconds).
'-[VoidTests.PipelineTests testDeleteRemovesMeetingAndRecording]' passed (0.021 seconds).
'-[VoidTests.PipelineTests testGlossaryParsing]' passed (0.009 seconds).
'-[VoidTests.PipelineTests testImmediateRetentionDeletesAudioAfterProcessing]' passed (0.032 seconds).
'-[VoidTests.PipelineTests testLiveTranscriptSkipsFileTranscription]' passed (8.069 seconds).
'-[VoidTests.PipelineTests testMissingAudioFileClearsStaleReference]' passed (0.032 seconds).
'-[VoidTests.PipelineTests testPlainHTTPWebhookIsNeverUsed]' passed (0.075 seconds).
'-[VoidTests.PipelineTests testPlainTextHasSummaryDecisionsAndTasks]' passed (0.179 seconds).
'-[VoidTests.PipelineTests testProcessTranscribesSummarizesAndDeliversSignedWebhook]' passed (0.043 seconds).
'-[VoidTests.PipelineTests testPurgeDeletesOnlyExpiredAudioOfProcessedMeetings]' passed (0.039 seconds).
'-[VoidTests.PipelineTests testRetentionCountsFromProcessingNotRecording]' passed (0.028 seconds).
'-[VoidTests.PipelineTests testServerErrorSchedulesPersistedRetry]' passed (0.033 seconds).
'-[VoidTests.PipelineTests testSummaryFailureMarksFailedAndReprocessRecovers]' passed (0.034 seconds).
'-[VoidTests.PipelineTests testTranscriptIsIncludedWhenOptedIn]' passed (0.033 seconds).
'-[VoidTests.PipelineTests testZeroRetentionClearsAlreadyProcessedAudio]' passed (0.021 seconds).
'-[VoidTests.SileroVADTests testBundledModelLoads]' passed (0.204 seconds).
'-[VoidTests.SileroVADTests testSilenceIsNotSpeech]' passed (0.085 seconds).
'-[VoidTests.SileroVADTests testSteadyNoiseIsMostlyNotSpeech]' passed (0.216 seconds).
'-[VoidTests.SileroVADTests testSynthesizedSpeechIsSpeech]' passed (14.692 seconds).
'-[VoidTests.WidgetRenderTests testLiveActivityAndWidgetRender]' passed (3.355 seconds).
'-[VoidUITests.ScreenshotTests testAccessibilityTextSize]' passed (25.416 seconds).
'-[VoidUITests.ScreenshotTests testDeleteFromContextMenu]' passed (32.963 seconds).
'-[VoidUITests.ScreenshotTests testEmptyState]' passed (8.143 seconds).
'-[VoidUITests.ScreenshotTests testRecordButtonFailsGracefullyWithoutMicrophone]' passed (49.886 seconds).
'-[VoidUITests.ScreenshotTests testScreensDark]' passed (38.751 seconds).
'-[VoidUITests.ScreenshotTests testScreensLight]' passed (50.077 seconds).
```
