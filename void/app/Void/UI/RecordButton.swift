import SwiftUI

/// The one control that matters. Idle: a solid disc. Recording: the disc lifts
/// (heavier shadow) and the glyph becomes a rounded square that breathes with input level.
struct RecordButton: View {
    let isRecording: Bool
    let level: Float
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Theme.surface)
                    .frame(width: 168, height: 168)
                    .elevation(isRecording ? .floating : .raised)

                RoundedRectangle(cornerRadius: isRecording ? 14 : 48, style: .continuous)
                    .fill(Theme.ink)
                    .frame(width: isRecording ? 56 : 96, height: isRecording ? 56 : 96)
                    .scaleEffect(isRecording ? 1 + CGFloat(min(level * 4, 0.12)) : 1)
            }
            .animation(.spring(duration: 0.35), value: isRecording)
            .animation(.easeOut(duration: 0.1), value: level)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRecording ? "녹음 정지" : "녹음 시작")
        .sensoryFeedback(.impact(weight: .medium), trigger: isRecording)
    }
}
