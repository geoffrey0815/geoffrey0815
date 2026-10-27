import SwiftUI

struct MeetingDetailView: View {
    let meeting: Meeting
    @State private var showTranscript = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if let error = meeting.errorMessage {
                    Card { Text(error).font(.subheadline).foregroundStyle(Theme.muted) }
                }

                if !meeting.summary.isEmpty {
                    DetailSection(title: "요약") {
                        Text(meeting.summary).font(.body)
                    }
                }
                if !meeting.decisions.isEmpty {
                    DetailSection(title: "결정사항") {
                        ForEach(meeting.decisions, id: \.self) { Bullet(text: $0) }
                    }
                }
                if !meeting.actionItems.isEmpty {
                    DetailSection(title: "할 일") {
                        ForEach(meeting.actionItems, id: \.task) { item in
                            Bullet(text: item.owner.map { "\(item.task) — \($0)" } ?? item.task, symbol: "square")
                        }
                    }
                }
                if !meeting.transcript.isEmpty {
                    DisclosureGroup("원문 (\(meeting.transcript.count)개 구간)", isExpanded: $showTranscript) {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(meeting.transcript.enumerated()), id: \.offset) { _, segment in
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    Text(Duration.seconds(segment.start).formatted(.time(pattern: .minuteSecond)))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(Theme.muted)
                                    Text(segment.text).font(.callout)
                                }
                            }
                        }
                        .padding(.top, 12)
                    }
                    .tint(Theme.ink)
                }
            }
            .foregroundStyle(Theme.ink)
            .padding(16)
        }
        .background(Theme.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if meeting.status == .ready, AppSettings.webhookURL != nil {
                Button("다시 보내기", systemImage: "arrow.up.circle") {
                    Task { await ProcessingPipeline.shared.deliver(meetingID: meeting.id, manual: true) }
                }
                .tint(Theme.ink)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(meeting.displayTitle)
                .font(.title2.weight(.semibold))
            HStack(spacing: 8) {
                Text(meeting.startedAt.formatted(date: .abbreviated, time: .shortened))
                if let endedAt = meeting.endedAt {
                    Text("·")
                    Text(Duration.seconds(endedAt.timeIntervalSince(meeting.startedAt))
                        .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
                }
                Spacer()
                StatusLabel(meeting: meeting)
            }
            .font(.subheadline)
            .foregroundStyle(Theme.muted)
        }
    }
}

private struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(Theme.muted)
            Card { VStack(alignment: .leading, spacing: 8) { content } }
        }
    }
}

private struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Theme.surface, in: .rect(cornerRadius: 16, style: .continuous))
            .elevation(.raised)
    }
}

private struct Bullet: View {
    let text: String
    var symbol = "circle.fill"

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: symbol == "circle.fill" ? 5 : 12))
                .foregroundStyle(Theme.muted)
            Text(text)
        }
    }
}
