import Testing
@testable import VoidCore

@Suite struct SilenceMonitorTests {
    let config = SilenceMonitor.Configuration(timeout: 60, warningLead: 10, minSpeechDuration: 0.5)

    /// Feeds `isSpeech` every 0.1 s from `from` (inclusive) to `to` (exclusive) and collects events.
    func feed(_ monitor: inout SilenceMonitor, speech: Bool, from: Double, to: Double) -> [(Double, SilenceMonitor.Event)] {
        var events: [(Double, SilenceMonitor.Event)] = []
        var t = from
        while t < to - 1e-9 {
            if let event = monitor.process(isSpeech: speech, at: t) { events.append((t, event)) }
            t += 0.1
        }
        return events
    }

    @Test func silenceFromStartWarnsThenTimesOut() {
        var monitor = SilenceMonitor(configuration: config)
        let events = feed(&monitor, speech: false, from: 0, to: 70)
        #expect(events.count == 2)
        #expect(events.first.map { abs($0.0 - 50) < 0.11 } == true)
        #expect(events.last.map { $0.1 == .timeout && abs($0.0 - 60) < 0.11 } == true)
    }

    @Test func noEventsAfterTimeout() {
        var monitor = SilenceMonitor(configuration: config)
        _ = feed(&monitor, speech: false, from: 0, to: 61)
        #expect(monitor.process(isSpeech: true, at: 62) == nil)
        #expect(monitor.process(isSpeech: false, at: 200) == nil)
    }

    @Test func sustainedSpeechResetsTimer() {
        var monitor = SilenceMonitor(configuration: config)
        _ = feed(&monitor, speech: false, from: 0, to: 40)
        _ = feed(&monitor, speech: true, from: 40, to: 42)
        #expect(monitor.silenceDuration(at: 42) == 0)
        // Silence restarts at 42, so nothing may fire before 42 + 50.
        let events = feed(&monitor, speech: false, from: 42, to: 90)
        #expect(events.isEmpty)
    }

    @Test func briefNoiseDoesNotResetTimer() {
        var monitor = SilenceMonitor(configuration: config)
        _ = feed(&monitor, speech: false, from: 0, to: 30)
        _ = feed(&monitor, speech: true, from: 30, to: 30.3) // a cough
        let events = feed(&monitor, speech: false, from: 30.3, to: 61)
        #expect(events.contains { $0.1 == .timeout })
    }

    @Test func speechAfterWarningCancelsIt() {
        var monitor = SilenceMonitor(configuration: config)
        _ = feed(&monitor, speech: false, from: 0, to: 55)
        let events = feed(&monitor, speech: true, from: 55, to: 56)
        #expect(events.map(\.1) == [.warningCancelled])
    }

    @Test func extendRestartsTimer() {
        var monitor = SilenceMonitor(configuration: config)
        _ = feed(&monitor, speech: false, from: 0, to: 55)
        #expect(monitor.extend(at: 55) == .warningCancelled)
        #expect(feed(&monitor, speech: false, from: 55, to: 104).isEmpty)
    }

    @Test func speechStartingJustBeforeTimeoutIsNotCutOff() {
        var monitor = SilenceMonitor(configuration: config)
        _ = feed(&monitor, speech: false, from: 0, to: 59.8)
        // Speech begins 0.2 s before the timeout and is confirmed 0.3 s after it.
        let events = feed(&monitor, speech: true, from: 59.8, to: 61)
        #expect(!events.contains { $0.1 == .timeout })
        #expect(events.map(\.1) == [.warningCancelled])
    }

    @Test func briefNoiseAtTimeoutDefersButStillStops() {
        var monitor = SilenceMonitor(configuration: config)
        _ = feed(&monitor, speech: false, from: 0, to: 59.8)
        #expect(feed(&monitor, speech: true, from: 59.8, to: 60.1).isEmpty) // a cough
        let events = feed(&monitor, speech: false, from: 60.1, to: 61)
        #expect(events.first?.1 == .timeout)
    }

    @Test func warningLeadIsClampedToTimeout() {
        let clamped = SilenceMonitor.Configuration(timeout: 5, warningLead: 99)
        #expect(clamped.warningLead == 5)
    }
}
