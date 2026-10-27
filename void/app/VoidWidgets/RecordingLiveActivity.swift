import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// Lock Screen banner and Dynamic Island while recording. Grayscale: the only
/// "alert" signal for the silence warning is weight and the countdown.
struct RecordingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingAttributes.self) { context in
            LockScreenView(state: context.state)
                .padding(16)
                .activityBackgroundTint(Theme.surface)
                .activitySystemActionForegroundColor(Theme.ink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "waveform").font(.title3)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.startedAt, style: .timer)
                        .font(.title3.monospacedDigit())
                        .frame(maxWidth: 80, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Controls(state: context.state)
                }
            } compactLeading: {
                Image(systemName: "waveform")
            } compactTrailing: {
                Text(context.state.startedAt, style: .timer)
                    .monospacedDigit()
                    .frame(maxWidth: 44)
            } minimal: {
                Image(systemName: "waveform")
            }
        }
    }
}

private struct LockScreenView: View {
    let state: RecordingAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("void", systemImage: "waveform")
                    .font(.headline)
                Spacer()
                Text(state.startedAt, style: .timer)
                    .font(.title2.monospacedDigit().weight(.medium))
                    .multilineTextAlignment(.trailing)
            }
            Controls(state: state)
        }
        .foregroundStyle(Theme.ink)
    }
}

private struct Controls: View {
    let state: RecordingAttributes.ContentState

    var body: some View {
        HStack {
            if let autoStopAt = state.autoStopAt {
                VStack(alignment: .leading, spacing: 2) {
                    Text("조용해서 곧 멈춰요").font(.subheadline.weight(.semibold))
                    Text(timerInterval: Date.now...max(autoStopAt, .now), countsDown: true)
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                Button(intent: KeepRecordingIntent()) {
                    Text("계속")
                }
                .tint(Theme.muted)
            } else {
                Spacer()
            }
            Button(intent: StopRecordingIntent()) {
                Label("정지", systemImage: "stop.fill")
            }
            .tint(Theme.ink)
        }
    }
}
