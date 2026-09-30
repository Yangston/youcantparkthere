import SwiftUI
import MapKit
import WatchKit
import ParkCore

struct DockMapView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @State private var camera: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832),
        span: MKCoordinateSpan(latitudeDelta: 0.009, longitudeDelta: 0.012)))
    @State private var follow = true
    @State private var lastViewportUpdate = Date.distantPast

    var body: some View {
        ZStack {
            stationMap
            if model.snapshot == nil { loadingControl }
            emptyState
        }
        .onAppear { if model.page == .map { resumeFollowing() } }
        .onChange(of: model.recenterRequest) { _, _ in resumeFollowing() }
        .onChange(of: model.page) { _, page in if page == .map { resumeFollowing() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && !isLuminanceReduced && model.page == .map { resumeFollowing() }
        }
        .onChange(of: isLuminanceReduced) { _, reduced in
            if !reduced && scenePhase == .active && model.page == .map { resumeFollowing() }
        }
        .accessibilityAction(named: "Show settings") { model.page = .settings }
    }

    private var stationMap: some View {
        Map(position: $camera) {
            if let origin = model.origin {
                Annotation("You", coordinate: origin.mapCoordinate) {
                    Circle().fill(.blue).frame(width: 8, height: 8)
                        .overlay(Circle().stroke(.white, lineWidth: 1.5))
                        .allowsHitTesting(false)
                }
            }
            ForEach(model.visibleStations) { station in
                Annotation(station.name, coordinate: station.coordinate.mapCoordinate) {
                    Button {
                        WKInterfaceDevice.current().play(.click)
                        model.sheet = .station(station.id)
                    } label: {
                        HStack(spacing: 1) {
                            Text(model.freshCount(station).map(String.init) ?? "–")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                            if model.mode == .bikes, (model.freshElectricCount(station) ?? 0) > 0 {
                                Image(systemName: "bolt.fill").font(.system(size: 7, weight: .bold))
                            }
                        }.foregroundStyle(.black)
                            .padding(.horizontal, 3).padding(.vertical, 2)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(pinColor(station), in: Capsule())
                            .overlay(Capsule().stroke(model.favorites.contains(station.id) ? .white : .clear, lineWidth: 2))
                            .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(MapControlButtonStyle())
                        .accessibilityIdentifier("station.\(station.id)")
                        .accessibilityValue(model.favorites.contains(station.id) ? "Favourite" : "")
                        .accessibilityLabel("\(station.name), \(availabilityText(station, model: model))")
                }.annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .onMapCameraChange(frequency: .continuous) { context in
            if camera.positionedByUser { follow = false }
            let now = Date()
            guard now.timeIntervalSince(lastViewportUpdate) >= 0.12 else { return }
            lastViewportUpdate = now
            updateViewport(context.region)
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            // Always apply final bounds, even after a very short gesture.
            if camera.positionedByUser { follow = false }
            updateViewport(context.region)
        }
        .onChange(of: model.origin) { _, _ in if follow && model.page == .map { recenter() } }
    }

    @ViewBuilder
    private var emptyState: some View {
        if model.snapshot?.stations.isEmpty == true {
            Text("No stations in this snapshot").font(.caption2).multilineTextAlignment(.center)
                .padding(8).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var loadingControl: some View {
        if model.snapshot == nil {
            if model.error != nil && !model.refreshing {
                Button { Task { await model.refresh(manual: true) } } label: {
                    Text("Retry stations").font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 8).frame(height: 28)
                        .foregroundStyle(.orange).background(.regularMaterial, in: Capsule())
                        .frame(minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(MapControlButtonStyle()).accessibilityIdentifier("map.retry")
            } else {
                HStack(spacing: 4) {
                    ProgressView()
                    Text("Loading stations…").font(.system(size: 11))
                }.frame(height: 44).allowsHitTesting(false)
            }
        }
    }

    private func pinColor(_ station: Station) -> Color {
        guard let count = model.freshCount(station) else { return .gray }
        return count == 0 ? .red : count < 3 ? .yellow : .green
    }
    private func updateViewport(_ region: MKCoordinateRegion) {
        model.updateMapViewport(MapViewport(
            center: Coordinate(latitude: region.center.latitude, longitude: region.center.longitude),
            latitudeSpan: region.span.latitudeDelta, longitudeSpan: region.span.longitudeDelta))
    }
    private func resumeFollowing() { follow = true; recenter() }
    private func recenter() {
        let viewport = SimulatorPreview.initialViewport ?? MapViewport(center: model.center)
        model.updateMapViewport(viewport)
        camera = .region(MKCoordinateRegion(center: viewport.center.mapCoordinate,
            span: MKCoordinateSpan(latitudeDelta: viewport.latitudeSpan, longitudeDelta: viewport.longitudeSpan)))
    }
}

struct MapControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.55 : 1)
    }
}
