import SwiftUI
import WidgetKit

struct ParkingEntry: TimelineEntry { let date: Date }
struct ParkingProvider: TimelineProvider {
    func placeholder(in context: Context) -> ParkingEntry { ParkingEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (ParkingEntry) -> Void) {
        completion(ParkingEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ParkingEntry>) -> Void) {
        // A launcher, deliberately NOT a stale count pretending to be live.
        completion(Timeline(entries: [ParkingEntry(date: Date())], policy: .never))
    }
}
struct ParkingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let mode: String
    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                HStack {
                    Image(systemName: mode == "bikes" ? "bicycle" : "parkingsign.circle.fill").font(.title2)
                    VStack(alignment: .leading) {
                        Text(mode == "bikes" ? "Find a bike" : "Find a dock").font(.headline)
                        Text("Bike Share Toronto").font(.caption)
                    }
                }
            case .accessoryInline:
                Label(mode == "bikes" ? "Find bikes" : "Find docks", systemImage: mode == "bikes" ? "bicycle" : "parkingsign.circle")
            default:
                Image(systemName: mode == "bikes" ? "bicycle" : "parkingsign.circle.fill")
                    .font(.title).widgetAccentable()
            }
        }
        .containerBackground(for: .widget) { Color.orange.opacity(0.2) }
        .widgetURL(URL(string: "youcantparkthere://\(mode)")!)
        .accessibilityLabel(mode == "bikes" ? "Open nearby Bike Share bikes" : "Open nearby Bike Share empty docks")
    }
}
struct FindDocksWidget: Widget {
    let kind = "FindDocks"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ParkingProvider()) { _ in ParkingWidgetView(mode: "docks") }
            .configurationDisplayName("Find a Dock")
            .description("One tap to the parking map. Open the app for current availability.")
            .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}
struct FindBikesWidget: Widget {
    let kind = "FindBikes"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ParkingProvider()) { _ in ParkingWidgetView(mode: "bikes") }
            .configurationDisplayName("Find a Bike")
            .description("One tap to the nearby bikes map.")
            .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}
@main
struct ParkingWidgetBundle: WidgetBundle {
    var body: some Widget { FindDocksWidget(); FindBikesWidget() }
}
