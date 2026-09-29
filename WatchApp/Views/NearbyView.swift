import SwiftUI
import ParkCore

struct NearbyView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("showUnavailable") private var showUnavailable = false
    @State private var favoritesOnly = false
    @State private var selected: Station?
    private var items: [NearbyStation] {
        model.nearby(includeUnavailable: showUnavailable, limit: 100).filter { !favoritesOnly || model.favorites.contains($0.id) }
    }
    var body: some View {
        List {
            Text(model.mode == .docks ? "Nearby parking" : "Nearby bikes").font(.headline)
            Text("\(model.locationLabel) · straight-line distances").font(.caption2).foregroundStyle(.secondary)
            Toggle("Favorites", isOn: $favoritesOnly)
            if items.isEmpty {
                Text(model.snapshot?.isFresh(at: model.now) == true ? "No matches within 5 km. Try showing unavailable stations." : "No fresh availability. Check connection or show unavailable stations.")
                    .font(.caption)
            }
            ForEach(items) { item in
                Button { selected = item.station } label: {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.station.name).font(.system(size: 13, weight: .semibold))
                            Text(distanceText(item.distance)).font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 2)
                        Text(model.freshCount(item.station).map(String.init) ?? "–")
                            .font(.title3.bold()).foregroundStyle(.orange)
                    }
                }.accessibilityLabel("\(item.station.name), \(availabilityText(item.station, model: model)), \(distanceText(item.distance))")
            }
            Toggle("Show unavailable", isOn: $showUnavailable)
        }.sheet(item: $selected) { station in StationDetailView(stationID: station.id) }
    }
}
