import SwiftUI
import MapKit
import ParkCore

extension Coordinate {
    var mapCoordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}
func distanceText(_ meters: Double) -> String {
    meters < 1_000 ? "\(Int(meters.rounded())) m" : String(format: "%.1f km", meters / 1_000)
}
@MainActor
func availabilityText(_ station: Station, model: AppModel) -> String {
    guard let count = model.freshCount(station) else { return "Availability unknown or station unavailable" }
    if model.mode == .docks { return "\(count) empty docks" }
    let electric = model.freshElectricCount(station).map(String.init) ?? "unknown"
    return "\(count) bikes, e-bikes: \(electric)"
}
