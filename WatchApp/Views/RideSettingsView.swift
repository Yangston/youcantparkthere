import SwiftUI
import ParkCore

struct RideSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("autoDetect") private var autoDetect = false
    @AppStorage("suggestRide") private var suggestCycling = true
    var body: some View {
        List {
            Text("Settings").font(.headline)
            if model.locationDenied, let error = model.error {
                Text(error).font(.caption2).foregroundStyle(.orange)
            }
            Toggle("Automatic cycling", isOn: $autoDetect).onChange(of: autoDetect) { _, _ in model.settingsChanged() }
            Text(model.motionStatus).font(.caption2).foregroundStyle(.secondary)
            Text("Detects sustained cycling while this app can run, switches to Park, and stops after sustained walking, driving, or a longer standstill. Turn this off to stop detection and background navigation immediately. A closed app cannot detect cycling.")
                .font(.caption2).foregroundStyle(.secondary)
            Toggle("Cycling shortcut", isOn: $suggestCycling).onChange(of: suggestCycling) { _, _ in model.cyclingSuggestionChanged() }
            Text(model.cyclingSuggestionStatus).font(.caption2).foregroundStyle(.secondary)
            Text("Requests a Smart Stack suggestion after cycling is detected. watchOS chooses placement and clock-screen hints; the app cannot force the top position.")
                .font(.caption2).foregroundStyle(.secondary)
            Button(model.refreshing ? "Refreshing…" : "Refresh stations") { Task { await model.refresh(manual: true) } }.disabled(model.refreshing)
            Button("Enable / check GPS") { model.requestLocation() }
            Text(model.locationLabel).font(.caption2).foregroundStyle(.secondary)
            Text("In Bikes mode, a lightning mark means e-bikes are available. Tap a station for the e-bike count. A dash means unknown, not zero.")
                .font(.caption2).foregroundStyle(.secondary)
            if !model.locationDenied, let error = model.error { Text(error).font(.caption2).foregroundStyle(.orange) }
            Text("Keep the map handy").font(.headline)
            Text("Watch Settings → General → Return to Clock → this app → After 1 hour. Add the Find Docks complication for one-tap access.")
                .font(.caption2)
            Text("Detected cycling uses background location for navigation, up to 90 minutes, with a five-minute restart pause after the time limit or opt-out. No workout is recorded. Detection cannot guarantee updates while watchOS suspends the app.").font(.caption2)
            Text("Legal & data").font(.headline)
            Link("Apple Maps terms", destination: URL(string: "https://www.apple.com/legal/internet-services/maps/terms-en.html")!)
                .font(.caption2)
            Text("Data: Bike Share Toronto / Toronto Parking Authority (GBFS). Unofficial app; no account, analytics, or location upload to our own server.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}
