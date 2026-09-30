import SwiftUI
import MapKit
import ParkCore

struct DockMapView: View {
    @EnvironmentObject private var model: AppModel
    @State private var camera: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832),
        span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.016)))
    @State private var follow = true

    var body: some View {
        ZStack {
            stationMap
            VStack(spacing: 0) {
                controls.padding(.top, 2)
                Spacer(minLength: 0)
                footer.padding(.bottom, 2)
            }.padding(.horizontal, 6)
            HStack {
                Spacer()
                utilityControls
            }.padding(.horizontal, 6)
            loadingState
        }
    }

    private var stationMap: some View {
        Map(position: $camera) {
            if let origin = model.origin {
                Annotation("You", coordinate: origin.mapCoordinate) {
                    Circle().fill(.blue).frame(width: 8, height: 8)
                        .overlay(Circle().stroke(.white, lineWidth: 1.5))
                }
            }
            ForEach(model.mapStations()) { item in
                Annotation(item.station.name, coordinate: item.station.coordinate.mapCoordinate) {
                    Button { model.sheet = .station(item.id) } label: {
                        HStack(spacing: 1) {
                            Text(model.freshCount(item.station).map(String.init) ?? "–")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                            if model.mode == .bikes,
                               model.bikeFilter == .electric || (model.freshCount(item.station, mode: .bikes, bikeFilter: .electric) ?? 0) > 0 {
                                Image(systemName: "bolt.fill").font(.system(size: 7, weight: .bold))
                            }
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 3).padding(.vertical, 2)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(pinColor(item.station), in: Capsule())
                        .overlay(Capsule().stroke(model.targetID == item.id ? .white : .clear, lineWidth: 2))
                        // Keep an easier tap region while reducing the visible marker.
                        .padding(5).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .accessibilityLabel("\(item.station.name), \(availabilityText(item.station, model: model))")
                }.annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .ignoresSafeArea()
        .onMapCameraChange(frequency: .onEnd) { _ in if camera.positionedByUser { follow = false } }
        .onChange(of: model.origin) { _, _ in if follow { recenter() } }
    }

    @ViewBuilder
    private var loadingState: some View {
        if model.snapshot == nil {
            VStack(spacing: 5) {
                if model.refreshing { ProgressView() }
                Text(model.error == nil ? "Loading stations…" : "Stations unavailable")
                    .font(.caption2).multilineTextAlignment(.center)
                if model.error != nil { Button("Retry") { Task { await model.refresh() } } }
            }.padding(8).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 15)
        } else if model.snapshot?.stations.isEmpty == true {
            Text("No stations in this snapshot").font(.caption2).multilineTextAlignment(.center)
                .padding(8).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var controls: some View {
        HStack(spacing: 4) {
            Button { model.mode = model.mode == .docks ? .bikes : .docks } label: {
                Label(model.mode == .bikes && model.bikeFilter == .electric ? "E-bikes" : model.mode.title, systemImage: model.mode.symbol)
                    .font(.system(size: 12, weight: .bold)).padding(.horizontal, 6).frame(height: 28)
            }.buttonStyle(.plain).background(.regularMaterial, in: Capsule())
                .accessibilityHint("Switch between parking and bikes")
            Spacer(minLength: 0)

        }
    }

    private var utilityControls: some View {
        VStack(spacing: 6) {
            Button { follow = true; recenter(); model.requestLocation() } label: {
                Image(systemName: "location.fill").font(.system(size: 11)).frame(width: 28, height: 28)
            }.buttonStyle(.plain).background(.regularMaterial, in: Circle())
                .accessibilityLabel("Recenter on my location")
            Button { model.sheet = .settings } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 11)).frame(width: 28, height: 28)
            }.buttonStyle(.plain).background(.regularMaterial, in: Circle())
                .accessibilityLabel("Ride and settings")
        }
    }

    private var footer: some View {
        VStack(spacing: 3) {
            if let target = model.target {
                Button { model.sheet = .station(target.id) } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "flag.fill")
                        Text(target.name).lineLimit(1)
                        Spacer(minLength: 0)
                        Text(model.freshCount(target, mode: .docks).map { "\($0) P" } ?? "– P").bold()
                    }.font(.system(size: 9)).padding(.horizontal, 6).padding(.vertical, 4)
                }.buttonStyle(.plain).background(.regularMaterial, in: Capsule())
            }
            HStack(spacing: 4) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.locationLabel).lineLimit(2)
                        .foregroundStyle(model.isDemo ? .orange : .primary)
                    Text(model.error == nil ? model.freshnessLabel : "Connection issue · settings")
                        .foregroundStyle(model.error == nil ? Color.secondary : Color.orange)
                }.font(.system(size: 8)).lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                if model.mode == .bikes {
                    Button { model.bikeFilter = model.bikeFilter == .all ? .electric : .all } label: {
                        Image(systemName: model.bikeFilter == .electric ? "bolt.fill" : "bolt")
                            .font(.system(size: 12, weight: .bold)).frame(width: 28, height: 28)
                            .foregroundStyle(model.bikeFilter == .electric ? .orange : .primary)
                    }.buttonStyle(.plain).background(.regularMaterial, in: Circle())
                        .accessibilityLabel(model.bikeFilter == .electric ? "E-bikes only. Show all bikes" : "All bikes. Show e-bikes only")
                }
                Button { model.riding ? model.stopRide() : model.startRide() } label: {
                    Label(model.riding ? "End" : "Ride", systemImage: model.riding ? "stop.fill" : "bicycle")
                        .font(.system(size: 11, weight: .bold)).lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false).frame(minHeight: 28)
                }.buttonStyle(.plain).foregroundStyle(.orange)
            }.padding(.horizontal, 6).padding(.vertical, 3)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 11))
        }
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
