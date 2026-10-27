import SwiftUI
import WidgetKit

@main
struct VoidWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RecordWidget()
        RecordControl()
        RecordingLiveActivity()
    }
}
