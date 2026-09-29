import SwiftUI
import MapKit
import ParkCore

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("onboarded") private var onboarded = false
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    var body: some View {
        TabView(selection: $model.tab) {
            DockMapView().tag(0)
            NearbyView().tag(1)
            RideSettingsView().tag(2)
        }
        .tabViewStyle(.page)
        .tint(.orange)
        .onReceive(timer) { _ in model.tick() }
        .sheet(isPresented: Binding(get: { !onboarded && !model.isDemo }, set: { onboarded = !$0 })) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "parkingsign.circle.fill").font(.largeTitle).foregroundStyle(.orange)
                    Text("You Can't\nPark There").font(.title2.bold())
                    Text("Find a bike. Find an empty dock. Leave your phone in your pocket.")
                    Text("Start Ride keeps navigation active. Auto-detection works only while this app is running—not from a closed app.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Enable location") { onboarded = true; model.requestLocation() }.buttonStyle(.borderedProminent)
                    Button("Browse downtown") { onboarded = true }
                    Text("Not affiliated with Bike Share Toronto. Availability can change. Stop safely before interacting.")
                        .font(.caption2).foregroundStyle(.secondary)
                }.padding()
            }
        }
        .alert("That station is full", isPresented: Binding(get: { model.fullTarget != nil }, set: { if !$0 { model.fullTarget = nil } })) {
            Button("Find another") { model.clearTarget(); model.mode = .docks; model.tab = 1 }
            Button("Dismiss", role: .cancel) { model.fullTarget = nil }
        } message: { Text(model.fullTarget ?? "") }
    }
}

struct DockMapView: View {
    @EnvironmentObject private var model: AppModel
    @State private var camera: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832),
        span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.016)))
    @State private var selected: Station?
    @State private var follow = true
    var body: some View {
        VStack(spacing: 3) {
            HStack {
                Button { model.mode = model.mode == .docks ? .bikes : .docks } label: {
                    Label(model.mode.title, systemImage: model.mode.symbol).font(.headline)
                }.buttonStyle(.plain).accessibilityHint("Switch between empty docks and available bikes")
                Spacer()
                Button { follow = true; recenter(); model.requestLocation() } label: {
                    Image(systemName: "location.fill").frame(width: 34, height: 30)
                }.buttonStyle(.plain).accessibilityLabel("Recenter on my location")
            }
            Text(model.locationLabel).font(.system(size: 10)).foregroundStyle(model.isDemo ? .orange : .secondary)
            Map(position: $camera) {
                if let origin = model.origin {
                    Annotation("You", coordinate: origin.mapCoordinate) {
                        Circle().fill(.blue).frame(width: 10, height: 10).overlay(Circle().stroke(.white, lineWidth: 2))
                    }
                }
                ForEach(model.nearby()) { item in
                    Annotation(item.station.name, coordinate: item.station.coordinate.mapCoordinate) {
                        Button { selected = item.station } label: {
                            Text(model.freshCount(item.station).map(String.init) ?? "–")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundStyle(.black)
                                .frame(minWidth: 28, minHeight: 28)
                                .background(pinColor(item.station), in: Capsule())
                                .overlay(Capsule().stroke(model.targetID == item.id ? .white : .clear, lineWidth: 3))
                        }.buttonStyle(.plain)
                            .accessibilityLabel("\(item.station.name), \(availabilityText(item.station, model: model))")
                    }.annotationTitles(.hidden)
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onMapCameraChange(frequency: .onEnd) { _ in if camera.positionedByUser { follow = false } }
            .onChange(of: model.origin) { _, _ in if follow { recenter() } }
            .overlay {
                if model.snapshot == nil {
                    VStack(spacing: 6) {
                        if model.refreshing { ProgressView() }
                        Text(model.error == nil ? "Loading stations…" : "Stations unavailable").font(.caption)
                        if model.error != nil { Button("Retry") { Task { await model.refresh() } } }
                    }.padding(8).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
            }
            if let target = model.target {
                Button { selected = target } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "flag.fill")
                        Text(target.name).lineLimit(1)
                        Spacer(minLength: 0)
                        Text(model.freshCount(target, mode: .docks).map { "\($0) P" } ?? "– P").bold()
                    }.font(.system(size: 10))
                }.buttonStyle(.plain)
            }
            HStack(spacing: 4) {
                Text(model.freshnessLabel).font(.system(size: 9)).lineLimit(1)
                Spacer(minLength: 0)
                Button { model.riding ? model.stopRide() : model.startRide() } label: {
                    Label(model.riding ? "End" : "Ride", systemImage: model.riding ? "stop.fill" : "bicycle")
                        .font(.system(size: 11, weight: .bold))
                }.buttonStyle(.plain).foregroundStyle(.orange)
            }
            if model.error != nil { Text("Connection issue · see settings").font(.system(size: 9)).foregroundStyle(.orange) }
        }
        .padding(.horizontal, 5)
        .sheet(item: $selected) { station in StationDetailView(stationID: station.id) }
    }
    private func pinColor(_ station: Station) -> Color {
        guard let count = model.freshCount(station) else { return .gray }
        return count == 0 ? .red : count < 3 ? .yellow : .green
    }
    private func recenter() {
        camera = .region(MKCoordinateRegion(center: model.center.mapCoordinate,
                                           span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.016)))
    }
}

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
                        inventory("Bikes", count: model.freshCount(station, mode: .bikes))
                    }
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
            Text(count.map(String.init) ?? "–").font(.system(size: 34, weight: .heavy, design: .rounded)).foregroundStyle(.orange)
            Text(title).font(.caption)
        }
    }
}

struct RideSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("autoDetect") private var autoDetect = false
    @AppStorage("minimumDocks") private var minimumDocks = 1
    var body: some View {
        List {
            Text("Ride & settings").font(.headline)
            if let start = model.ridingSince { Text(start, style: .timer).font(.title2.monospacedDigit()) }
            Button(model.riding ? "End ride" : "Start ride") { model.riding ? model.stopRide() : model.startRide() }
                .tint(model.riding ? .red : .orange)
            Toggle("Detect cycling", isOn: $autoDetect).onChange(of: autoDetect) { _, _ in model.settingsChanged() }
            Text(model.motionStatus).font(.caption2).foregroundStyle(.secondary)
            Text("Switches to parking after sustained cycling while the app is open. Cannot launch a closed app. End rides manually; traffic lights won't stop them.")
                .font(.caption2).foregroundStyle(.secondary)
            Picker("Minimum docks", selection: $minimumDocks) {
                Text("1+").tag(1); Text("3+").tag(3); Text("5+").tag(5)
            }
            Text("Filters the available-stations list, not the map.").font(.caption2).foregroundStyle(.secondary)
            Button("Refresh stations") { Task { await model.refresh() } }.disabled(model.refreshing)
            Button("Enable / check GPS") { model.requestLocation() }
            if let error = model.error { Text(error).font(.caption2).foregroundStyle(.orange) }
            Text("Keep the map handy").font(.headline)
            Text("Watch Settings → General → Return to Clock → this app → After 1 hour. Add the Find Docks complication for one-tap access.")
                .font(.caption2)
            Text("Ride mode uses background location for navigation and may use more battery. It stops after 90 minutes. No HealthKit workout is created.").font(.caption2)
            Text("Data: Bike Share Toronto / Toronto Parking Authority (GBFS). Unofficial app; no account, analytics, or location upload to our own server.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

extension Coordinate {
    var mapCoordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}
extension Station {
    var mapsURL: URL {
        var components = URLComponents(string: "https://maps.apple.com/")!
        components.queryItems = [URLQueryItem(name: "ll", value: "\(coordinate.latitude),\(coordinate.longitude)"), URLQueryItem(name: "q", value: name)]
        return components.url!
    }
}
func distanceText(_ meters: Double) -> String {
    meters < 1_000 ? "\(Int(meters.rounded())) m" : String(format: "%.1f km", meters / 1_000)
}
@MainActor
func availabilityText(_ station: Station, model: AppModel) -> String {
    guard let count = model.freshCount(station) else { return "Availability unknown or station unavailable" }
    return "\(count) \(model.mode == .docks ? "empty docks" : "bikes")"
}
