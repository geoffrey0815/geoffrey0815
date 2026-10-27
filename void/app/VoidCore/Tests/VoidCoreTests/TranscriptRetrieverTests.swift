import Testing
@testable import VoidCore

@Suite struct TranscriptRetrieverTests {
    let chunks = [
        "오늘 회의는 4분기 로드맵 리뷰입니다. 참석자는 민지와 준호입니다.",
        "출시 일정은 12월 첫째 주로 확정했습니다. 마케팅은 그 다음 주에 시작합니다.",
        "화자 구분 기능은 정확도가 낮아서 1분기로 미루기로 했습니다.",
        "webhook 문서는 준호가 다음 주까지 정리합니다.",
    ]

    @Test func findsTheChunkAboutTheQuestion() {
        let result = TranscriptRetriever.relevantChunks(for: "출시는 언제로 정했어?", in: chunks, limit: 1)
        #expect(result == [chunks[1]])
    }

    @Test func ranksByMatchedTerms() {
        let result = TranscriptRetriever.relevantChunks(for: "준호가 webhook 문서 언제까지 해?", in: chunks, limit: 2)
        #expect(result.first == chunks[3])
    }

    @Test func fallsBackToOpeningWhenNothingMatches() {
        let result = TranscriptRetriever.relevantChunks(for: "날씨 어때?", in: chunks, limit: 2)
        #expect(result == Array(chunks.prefix(2)))
    }

    @Test func trimsKoreanParticles() {
        #expect(TranscriptRetriever.terms(in: "출시는 일정을") == ["출시", "일정"])
        #expect(TranscriptRetriever.terms(in: "Webhook, API!") == ["webhook", "api"])
    }
}
