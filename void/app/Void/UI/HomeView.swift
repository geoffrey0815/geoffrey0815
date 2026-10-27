import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(RecordingController.self) private var recorder
    @Query(sort: \Meeting.startedAt, order: .reverse) private var meetings: [Meeting]
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    recorderSection
                        .padding(.top, 24)

                    LazyVStack(spacing: 12) {
                        ForEach(meetings) { meeting in
                            NavigationLink(value: meeting.id) {
                                MeetingRow(meeting: meeting)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("meeting-\(meeting.id)")
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(Theme.canvas.ignoresSafeArea())
            .navigationTitle("void")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("설정", systemImage: "gearshape") { showSettings = true }
                    .tint(Theme.ink)
            }
            .navigationDestination(for: String.self) { id in
                if let meeting = meetings.first(where: { $0.id == id }) {
                    MeetingDetailView(meeting: meeting)
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }

    private var recorderSection: some View {
        VStack(spacing: 20) {
            RecordButton(isRecording: recorder.isRecording, level: recorder.level) {
                Task { try? await recorder.toggle() }
            }

            Group {
                if case .recording(let startedAt) = recorder.phase {
                    Text(startedAt, style: .timer)
                        .font(.system(.title2, design: .monospaced, weight: .medium))
                        .foregroundStyle(Theme.ink)
                } else {
                    Text("누르면 녹음이 시작됩니다")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
            }
            .contentTransition(.opacity)

            if recorder.isInterrupted {
                Label("다른 앱이 마이크를 쓰는 중이라 잠시 멈췄어요", systemImage: "pause")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }

            if let autoStopAt = recorder.autoStopAt {
                SilenceWarning(autoStopAt: autoStopAt) {
                    Task { await recorder.keepRecording() }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if let error = recorder.lastError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
        }
        .animation(.easeInOut, value: recorder.autoStopAt)
    }
}

private struct SilenceWarning: View {
    let autoStopAt: Date
    let keepRecording: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("조용해서 곧 멈춰요")
                    .font(.subheadline.weight(.semibold))
                Text(timerInterval: Date.now...max(autoStopAt, .now), countsDown: true)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Button("계속 녹음", action: keepRecording)
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.bordered)
                .tint(Theme.ink)
        }
        .padding(16)
        .background(Theme.surface, in: .rect(cornerRadius: 16, style: .continuous))
        .elevation(.raised)
    }
}

private struct MeetingRow: View {
    let meeting: Meeting

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(meeting.displayTitle)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Spacer()
                StatusLabel(meeting: meeting)
            }
            if !meeting.summary.isEmpty {
                Text(meeting.summary)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(2)
            }
            Text(meeting.startedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.surface, in: .rect(cornerRadius: 16, style: .continuous))
        .elevation(.raised)
    }
}

struct StatusLabel: View {
    let meeting: Meeting

    var body: some View {
        switch meeting.status {
        case .recording: label("녹음 중", "record.circle")
        case .transcribing: label("받아쓰는 중", "waveform")
        case .summarizing: label("요약 중", "text.alignleft")
        case .failed: label("실패", "exclamationmark.triangle")
        case .ready:
            switch meeting.delivery {
            case .delivered: label("전송됨", "checkmark")
            case .pending: label("전송 중", "arrow.up")
            case .failed: label("전송 실패", "exclamationmark.triangle")
            case .notConfigured: EmptyView()
            }
        }
    }

    private func label(_ text: String, _ symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.medium))
            .foregroundStyle(Theme.muted)
            .labelStyle(.titleAndIcon)
    }
}
