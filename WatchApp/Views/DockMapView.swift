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
        span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.016)))
    @State private var follow = true
    @State private var lastViewportUpdate = Date.distantPast

    var body: some View {
        ZStack {
            // Only the map draws outside the safe area. Controls stay tappable.
            stationMap.ignoresSafeArea()
            VStack(spacing: 0) {
                controls
                Spacer(minLength: 0)
                footer
            }.padding(.horizontal, 2).zIndex(1)
            loadingState
        }
        .onAppear { if model.page == .map { resumeFollowing() } }
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
                            .overlay(Capsule().stroke(model.targetID == station.id ? .white : .clear, lineWidth: 2))
                            .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(MapControlButtonStyle())
                        .accessibilityIdentifier("station.\(station.id)")
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
    private var loadingState: some View {
        if model.snapshot == nil {
            VStack(spacing: 5) {
                if model.refreshing { ProgressView() }
                Text(model.error == nil ? "Loading stations…" : "Stations unavailable")
                    .font(.caption2).multilineTextAlignment(.center)
                if model.error != nil {
                    Button("Retry") { Task { await model.refresh() } }.frame(minHeight: 44)
                }
            }.padding(8).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 15)
        } else if model.snapshot?.stations.isEmpty == true {
            Text("No stations in this snapshot").font(.caption2).multilineTextAlignment(.center)
                .padding(8).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .allowsHitTesting(false)
        }
    }

    private var controls: some View {
        HStack(spacing: 0) {
            Button {
                model.mode = model.mode == .docks ? .bikes : .docks
                WKInterfaceDevice.current().play(.click)
            } label: {
                Label(model.mode.title, systemImage: model.mode.symbol)
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 6).frame(height: 28)
                    .background(.regularMaterial, in: Capsule())
                    .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(MapControlButtonStyle())
                .accessibilityIdentifier("map.mode")
                .accessibilityHint("Switch between parking and bikes")
            Spacer(minLength: 0)
            Button {
                resumeFollowing(); model.requestLocation()
                WKInterfaceDevice.current().play(.click)
            } label: {
                Image(systemName: "location.fill").font(.system(size: 12))
                    .frame(width: 28, height: 28)
                    .background(.regularMaterial, in: Circle())
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }.buttonStyle(MapControlButtonStyle())
                .accessibilityIdentifier("map.recenter")
                .accessibilityLabel("Recenter on my location")
                .accessibilityValue(model.locationLabel)
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            if let target = model.target {
                Button { model.sheet = .station(target.id) } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "flag.fill")
                        Text(target.name).lineLimit(1)
                        Spacer(minLength: 0)
                        Text(model.freshCount(target, mode: .docks).map { "\($0) P" } ?? "– P").bold()
                    }.font(.system(size: 9)).padding(.horizontal, 6).frame(height: 24)
                        .background(.regularMaterial, in: Capsule())
                        .frame(minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(MapControlButtonStyle())
                    .accessibilityIdentifier("map.destination")
            }
            HStack(alignment: .top, spacing: 4) {
                Text(model.freshnessLabel)
                    .font(.system(size: 9)).lineLimit(2).minimumScaleFactor(0.8)
                    .foregroundStyle(model.isDemo || model.snapshot?.isFresh(at: model.now) != true ? Color.orange : Color.primary)
                    .padding(.horizontal, 4).padding(.vertical, 3)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9))
                    .padding(.top, 8)
                    .accessibilityHint("Swipe left along the bottom for settings.")
                Spacer(minLength: 0)
                Button { model.riding ? model.stopRide() : model.startRide() } label: {
                    Label(model.riding ? "End" : "Ride", systemImage: model.riding ? "stop.fill" : "bicycle")
                        .font(.system(size: 11, weight: .bold)).lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false).padding(.horizontal, 5).frame(height: 28)
                        .foregroundStyle(.orange).background(.regularMaterial, in: Capsule())
                        .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(MapControlButtonStyle())
                    .accessibilityIdentifier("map.ride")
            }
            .contentShape(Rectangle())
            // A swipe area outside MapKit's pan recognizer preserves map dragging.
            .simultaneousGesture(DragGesture(minimumDistance: 24).onEnded { value in
                if value.translation.width < -35 && abs(value.translation.width) > abs(value.translation.height) * 1.5 {
                    model.page = .settings
                }
            })
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

private struct MapControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.55 : 1)
    }
}
