import WidgetKit
import SwiftUI

@main
struct tuneLinkWidgetBundle: WidgetBundle {
    var body: some Widget {
        tuneLinkWidget()
        if #available(iOS 16.2, *) {
            TuneLinkLiveActivityView()
        }
    }
}

struct tuneLinkWidget: Widget {
    let kind = "tuneLinkWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            tuneLinkWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("tuneLink")
        .description("See what your friends are listening to.")
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
    let entry: GroupEntry

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
