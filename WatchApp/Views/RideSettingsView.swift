import SwiftUI
import ParkCore

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
