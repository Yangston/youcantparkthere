import SwiftUI
import MapKit
import ParkCore

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
