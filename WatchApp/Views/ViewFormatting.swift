import SwiftUI
import MapKit
import ParkCore

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
