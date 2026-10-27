import Testing
@testable import VoidCore

@Suite struct SpeechWindowingTests {
    typealias Span = SpeechWindowing.Span

    @Test func mergesCloseNeighbours() {
        let spans = [Span(start: 0, end: 3), Span(start: 4, end: 8), Span(start: 9, end: 20)]
        #expect(SpeechWindowing.windows(for: spans) == [Span(start: 0, end: 20)])
    }

    @Test func longGapStartsNewWindow() {
        let spans = [Span(start: 0, end: 3), Span(start: 10, end: 12)]
        #expect(SpeechWindowing.windows(for: spans) == spans)
    }

    @Test func windowNeverExceedsTarget() {
        let spans = (0..<20).map { Span(start: Double($0) * 4, end: Double($0) * 4 + 3) }
        let windows = SpeechWindowing.windows(for: spans)
        #expect(windows.allSatisfy { $0.duration <= 25 })
        #expect(windows.first == Span(start: 0, end: 23))
    }

    @Test func overLongSpanIsSplitNotTruncated() {
        let windows = SpeechWindowing.windows(for: [Span(start: 100, end: 165)])
        #expect(windows.count == 3)
        #expect(windows.allSatisfy { $0.duration <= 29.5 })
        #expect(windows.first?.start == 100)
        #expect(windows.last?.end == 165)
        for (a, b) in zip(windows, windows.dropFirst()) {
            #expect(a.end == b.start)
        }
    }

    @Test func dropsEmptySpans() {
        #expect(SpeechWindowing.windows(for: [Span(start: 5, end: 5)]).isEmpty)
    }
}
