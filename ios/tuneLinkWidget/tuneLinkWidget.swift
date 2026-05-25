import WidgetKit
import SwiftUI

// 12.4 — Register both widget families
struct tuneLinkWidget: Widget {
    let kind = "tuneLinkWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            tuneLinkWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("tuneLink")
        .description("See what your partner is listening to.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryRectangular,
            .accessoryCircular,
        ])
    }
}

struct tuneLinkWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: NowPlayingEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            AccessoryRectangularView(entry: entry)
        case .accessoryCircular:
            AccessoryCircularView(entry: entry)
        default:
            HomeWidgetView(entry: entry)
        }
    }
}
