import SwiftUI
import ParkCore

struct StationDetailView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let stationID: String
    var body: some View {
        ScrollView {
            if let station = model.snapshot?.stations.first(where: { $0.id == stationID }) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(station.name).font(.headline)
                    Text("\(distanceText(model.center.distance(to: station.coordinate))) · straight line").font(.caption2)
                    HStack {
                        inventory("Docks", count: model.freshCount(station, mode: .docks))
                        Spacer()
                        inventory("Bikes", count: model.freshCount(station, mode: .bikes, bikeFilter: .all))
                        Spacer()
                        inventory("E-bikes", count: model.freshCount(station, mode: .bikes, bikeFilter: .electric))
                    }
                    Text("E-bikes are included in the total bikes.").font(.caption2).foregroundStyle(.secondary)
                    if !(model.snapshot?.isFresh(station, at: model.now) ?? false) {
                        Text("Availability unknown or stale. Refresh before choosing this station.").font(.caption).foregroundStyle(.orange)
                    } else if !station.operational(for: model.mode) {
                        Text(model.mode == .docks ? "Not accepting returns" : "Not renting bikes").font(.caption).foregroundStyle(.orange)
                    }
                    Button(model.targetID == station.id ? "Clear destination" : "Make destination") {
                        if model.targetID == station.id { model.clearTarget() } else { model.chooseTarget(station) }
                        dismiss()
                    }.buttonStyle(.borderedProminent)
                        .disabled(model.targetID != station.id && (model.freshCount(station, mode: .docks) ?? 0) == 0)
                    Button(model.favorites.contains(station.id) ? "Unfavorite" : "Favorite") { model.toggleFavorite(station.id) }
                    Link("Open in Apple Maps", destination: station.mapsURL)
                    Text(model.freshnessLabel).font(.caption2).foregroundStyle(.secondary)
                    Text("Counts are not reservations. A proximity tap is not confirmation that your bike is docked. Verify the dock's return signal.")
                        .font(.caption2).foregroundStyle(.secondary)
                }.padding()
            } else { Text("Station no longer in the feed.").padding() }
        }
    }
    private func inventory(_ title: String, count: Int?) -> some View {
        VStack(alignment: .leading) {
            Text(count.map(String.init) ?? "–").font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(.orange).lineLimit(1).minimumScaleFactor(0.7)
            Text(title).font(.caption2)
        }
    }
}
