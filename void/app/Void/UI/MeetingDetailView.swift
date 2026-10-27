import SwiftUI
import UIKit

struct MeetingDetailView: View {
    let meeting: Meeting
    @Environment(\.dismiss) private var dismiss
    @State private var showTranscript = false
    @State private var confirmDelete = false

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
                if meeting.status == .ready {
                    AskSection(meeting: meeting)
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
            if meeting.status == .failed, meeting.audioURL != nil {
                Button("다시 처리", systemImage: "arrow.clockwise") {
                    Task { await ProcessingPipeline.shared.reprocess(meetingID: meeting.id) }
                }
                .tint(Theme.ink)
            }
            Menu("더보기", systemImage: "ellipsis") {
                if meeting.status == .ready {
                    ShareLink(item: meeting.plainText) { Label("공유", systemImage: "square.and.arrow.up") }
                    Button("복사", systemImage: "doc.on.doc") { UIPasteboard.general.string = meeting.plainText }
                    if AppSettings.webhookURL != nil {
                        Button("Webhook 다시 보내기", systemImage: "arrow.up.circle") {
                            Task { await ProcessingPipeline.shared.deliver(meetingID: meeting.id, manual: true) }
                        }
                    }
                }
                Button("삭제", systemImage: "trash") { confirmDelete = true }
            }
            .tint(Theme.ink)
        }
        .confirmationDialog("이 회의와 녹음을 삭제할까요?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("삭제") {
                // Leave the screen first: a view must not render a model that is gone.
                let id = meeting.id
                dismiss()
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    ProcessingPipeline.shared.delete(meetingID: id)
                }
            }
        }
    }

    private var when: some View {
        HStack(spacing: 8) {
            Text(meeting.startedAt.formatted(date: .abbreviated, time: .shortened))
            if let endedAt = meeting.endedAt {
                Text("·")
                Text(Duration.seconds(endedAt.timeIntervalSince(meeting.startedAt))
                    .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(meeting.displayTitle)
                .font(.title2.weight(.semibold))
            // One line when it fits; stacked at large text sizes, where one line squeezed the
            // date into a word-per-line column.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    when.fixedSize()
                    Spacer()
                    StatusLabel(meeting: meeting)
                }
                VStack(alignment: .leading, spacing: 4) {
                    when
                    StatusLabel(meeting: meeting)
                }
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

/// "질문하기": ask the on-device model about this meeting. Answers stay on screen only.
private struct AskSection: View {
    let meeting: Meeting
    @State private var question = ""
    @State private var exchanges: [(question: String, answer: String)] = []
    @State private var isAnswering = false
    @FocusState private var focused: Bool

    var body: some View {
        DetailSection(title: "질문하기") {
            ForEach(Array(exchanges.enumerated()), id: \.offset) { _, exchange in
                VStack(alignment: .leading, spacing: 4) {
                    Text(exchange.question)
                        .font(.subheadline.weight(.semibold))
                    Text(exchange.answer)
                        .font(.callout)
                        .foregroundStyle(Theme.muted)
                }
                .padding(.bottom, 4)
            }
            HStack(spacing: 8) {
                TextField("이 회의에 대해 물어보세요", text: $question, axis: .vertical)
                    .lineLimit(1...3)
                    .focused($focused)
                    .submitLabel(.send)
                    .onSubmit(ask)
                    .accessibilityIdentifier("ask-field")
                if isAnswering {
                    ProgressView()
                } else {
                    Button("보내기", systemImage: "arrow.up.circle.fill", action: ask)
                        .labelStyle(.iconOnly)
                        .font(.title2)
                        .tint(Theme.ink)
                        .disabled(question.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func ask() {
        let asked = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !asked.isEmpty, !isAnswering else { return }
        let notes = MeetingNotes(meeting)
        question = ""
        focused = false
        isAnswering = true
        Task {
            let answer: String
            do {
                answer = try await Answerers.current.answer(asked, about: notes)
            } catch {
                answer = error.localizedDescription
            }
            exchanges.append((asked, answer))
            isAnswering = false
        }
    }
}
