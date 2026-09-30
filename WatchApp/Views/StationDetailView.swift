import SwiftUI
import ParkCore

struct StationDetailView: View {
    @EnvironmentObject private var model: AppModel
    let stationID: String
    var body: some View {
        ScrollView {
            if let station = model.snapshot?.stations.first(where: { $0.id == stationID }) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(station.name).font(.headline)
                    Text(distanceText(model.center.distance(to: station.coordinate))).font(.caption2)
                    HStack {
                        inventory("Docks", count: model.freshCount(station, mode: .docks))
                        Spacer()
                        inventory("Bikes", count: model.freshStandardCount(station))
                        Spacer()
                        inventory("E-bikes", count: model.freshElectricCount(station))
                    }
                    if !(model.snapshot?.isFresh(station, at: model.now) ?? false) {
                        Text("Availability unknown or stale.").font(.caption).foregroundStyle(.orange)
                    } else if !station.operational(for: model.mode) {
                        Text(model.mode == .docks ? "Not accepting returns" : "Not renting bikes").font(.caption).foregroundStyle(.orange)
                    }
                    Button(model.favorites.contains(station.id) ? "Unfavourite" : "Favourite") { model.toggleFavorite(station.id) }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("station.favorite")
                    Text(model.freshnessLabel).font(.caption2).foregroundStyle(.secondary)
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
