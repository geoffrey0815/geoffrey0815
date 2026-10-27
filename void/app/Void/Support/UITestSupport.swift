#if DEBUG
import SwiftData
import SwiftUI
import VoidCore

/// Launch arguments used by VoidUITests to render every screen state deterministically:
/// `-uiTestSeed` swaps in an in-memory store with sample meetings, `-uiTestDark` forces
/// dark mode. Compiled into Debug builds only.
enum UITestSupport {
    static var isActive: Bool { ProcessInfo.processInfo.arguments.contains("-uiTestSeed") }

    static var colorScheme: ColorScheme? {
        guard isActive else { return nil }
        return ProcessInfo.processInfo.arguments.contains("-uiTestDark") ? .dark : .light
    }

    @MainActor
    static func makeSeededContainer() -> ModelContainer {
        let container = try! ModelContainer(
            for: Meeting.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        if ProcessInfo.processInfo.arguments.contains("-uiTestEmpty") { return container }
        let now = Date.now

        let review = Meeting(startedAt: now.addingTimeInterval(-2 * 3600), language: "ko-KR")
        review.id = "mtg_seed_review"
        review.endedAt = review.startedAt.addingTimeInterval(42 * 60 + 13)
        review.endReason = .silenceTimeout
        review.status = .ready
        review.delivery = .delivered
        review.title = "Q4 로드맵 리뷰"
        review.summary = "4분기 출시 범위와 일정을 검토했다. 위젯 녹음 시작과 webhook 연동을 1차 범위로 확정하고, 화자 구분은 다음 분기로 미뤘다. 베타 테스터 모집은 다음 주에 시작한다."
        review.decisions = ["출시는 12월 첫째 주", "화자 구분은 1분기로 연기"]
        review.actionItems = [
            .init(task: "베타 테스터 모집 공지 작성하기", owner: "민지"),
            .init(task: "webhook 문서 정리하기", owner: "준호", due: "11/3"),
            .init(task: "앱 아이콘 최종안 고르기"),
        ]
        review.transcript = [
            .init(start: 0, end: 6, text: "자, 4분기 로드맵 리뷰 시작하겠습니다."),
            .init(start: 6, end: 15, text: "먼저 출시 범위부터 볼게요. 위젯이랑 webhook은 확정이죠?"),
            .init(start: 15, end: 24, text: "네, 그 두 개는 이번에 꼭 들어가야 합니다."),
            .init(start: 24, end: 33, text: "화자 구분은 아직 정확도가 낮아서 다음 분기로 미루는 게 좋겠어요."),
        ]
        review.audioFileName = nil

        let standup = Meeting(startedAt: now.addingTimeInterval(-26 * 3600), language: "ko-KR")
        standup.id = "mtg_seed_standup"
        standup.endedAt = standup.startedAt.addingTimeInterval(14 * 60)
        standup.endReason = .manual
        standup.status = .ready
        standup.delivery = .pending
        standup.title = "데일리 스탠드업"
        standup.summary = "어제 작업과 오늘 계획을 공유했다. 녹음 중단 처리 버그를 우선 고치기로 했다."
        standup.errorMessage = "Webhook 전송 실패 (HTTP 503) — 다시 시도합니다."
        standup.audioFileName = nil

        let failed = Meeting(startedAt: now.addingTimeInterval(-50 * 3600), language: "ko-KR")
        failed.id = "mtg_seed_failed"
        failed.endedAt = failed.startedAt.addingTimeInterval(31 * 60)
        failed.status = .failed
        failed.errorMessage = "Apple Intelligence를 켜야 요약할 수 있습니다."

        let processing = Meeting(startedAt: now.addingTimeInterval(-5 * 60), language: "ko-KR")
        processing.id = "mtg_seed_processing"
        processing.endedAt = now.addingTimeInterval(-60)
        processing.status = .summarizing
        processing.audioFileName = nil

        [review, standup, failed, processing].forEach(context.insert)
        try? context.save()
        return container
    }
}
#endif
