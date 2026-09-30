import SwiftUI
import WatchKit
import ParkCore

/// Transparent controls and swipe surface over the bottom of the map.
struct BottomNavigationView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        VStack(spacing: 0) {
            if model.page == .map {
                HStack(spacing: 2) {
                    Text(model.freshnessLabel)
                        .font(.system(size: 8)).lineLimit(2).minimumScaleFactor(0.75)
                        .foregroundStyle(model.isDemo || model.snapshot?.isFresh(at: model.now) != true ? Color.orange : Color.primary)
                        .padding(.horizontal, 3).padding(.vertical, 3)
                        .mapGlass(in: RoundedRectangle(cornerRadius: 7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        model.recenterRequest += 1
                        model.requestLocation()
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        Image(systemName: "location.fill").font(.system(size: 12))
                            .frame(width: 28, height: 28)
                            .mapGlass(in: Circle(), interactive: true)
                            .frame(width: 44, height: 44).contentShape(Rectangle())
                    }.buttonStyle(MapControlButtonStyle())
                        .accessibilityIdentifier("map.recenter")
                        .accessibilityLabel("Recenter on my location")
                        .accessibilityValue(model.locationLabel)
                    Button {
                        model.mode = model.mode == .docks ? .bikes : .docks
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        Text(model.mode.title).font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 6).frame(height: 28)
                            .mapGlass(in: Capsule(), interactive: true)
                            .frame(minWidth: 44, maxWidth: .infinity, minHeight: 44, alignment: .trailing)
                            .contentShape(Rectangle())
                    }.buttonStyle(MapControlButtonStyle())
                        .accessibilityIdentifier("map.mode")
                        .accessibilityHint("Switch between parking and bikes")
                }.padding(.horizontal, 4).frame(height: 44)
            } else {
                Text("Swipe right for map").font(.system(size: 10)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).frame(height: 44)
            }
            HStack(spacing: 5) {
                Circle().fill(model.page == .map ? .white : .gray).frame(width: 5, height: 5)
                Circle().fill(model.page == .settings ? .white : .gray).frame(width: 5, height: 5)
            }.frame(maxWidth: .infinity).frame(height: 12)
                .accessibilityLabel(model.page == .map ? "Map, page 1 of 2" : "Settings, page 2 of 2")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: model.page = .settings
                    case .decrement: model.page = .map
                    @unknown default: break
                    }
                }
        }.frame(maxWidth: .infinity)
            .accessibilityAction(named: model.page == .map ? "Show settings" : "Show map") {
                model.page = model.page == .map ? .settings : .map
            }
    }
}
