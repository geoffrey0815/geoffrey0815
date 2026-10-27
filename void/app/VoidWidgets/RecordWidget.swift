import AppIntents
import SwiftUI
import WidgetKit

/// Home Screen and Lock Screen widget: a single record button.
struct RecordWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "void.record.widget", provider: Provider()) { _ in
            RecordWidgetView()
                .containerBackground(Theme.surface, for: .widget)
        }
        .configurationDisplayName("void 녹음")
        .description("앱을 열지 않고 바로 녹음을 시작합니다.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }

    struct Entry: TimelineEntry {
        let date: Date
    }

    struct Provider: TimelineProvider {
        func placeholder(in context: Context) -> Entry { Entry(date: .now) }
        func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) { completion(Entry(date: .now)) }
        func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
            completion(Timeline(entries: [Entry(date: .now)], policy: .never))
        }
    }
}

private struct RecordWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Button(intent: ToggleRecordingIntent()) {
            switch family {
            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "waveform").font(.title3)
                }
            default:
                VStack(spacing: 10) {
                    Circle()
                        .fill(Theme.ink)
                        .frame(width: 64, height: 64)
                        .elevation(.raised)
                    Text("녹음")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
