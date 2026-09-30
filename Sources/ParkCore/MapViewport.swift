import Foundation

/// Geographic camera bounds, independent of GPS and inventory freshness.
public struct MapViewport: Codable, Equatable, Sendable {
    public let center: Coordinate
    public let latitudeSpan: Double
    public let longitudeSpan: Double

    public init(center: Coordinate, latitudeSpan: Double = 0.009, longitudeSpan: Double = 0.012) {
        self.center = center
        self.latitudeSpan = latitudeSpan
        self.longitudeSpan = longitudeSpan
    }

    public var isValid: Bool {
        center.isValid && latitudeSpan.isFinite && longitudeSpan.isFinite
            && latitudeSpan > 0 && longitudeSpan > 0
    }

    /// A small overscan keeps markers from popping at the edge during a drag.
    public func contains(_ coordinate: Coordinate, overscan: Double = 0.1) -> Bool {
        guard isValid, coordinate.isValid, overscan.isFinite, overscan >= 0 else { return false }
        let halfLatitude = min(180, latitudeSpan) * (0.5 + overscan)
        let halfLongitude = min(360, longitudeSpan) * (0.5 + overscan)
        let longitudeDistance = abs((coordinate.longitude - center.longitude + 540)
            .truncatingRemainder(dividingBy: 360) - 180)
        return abs(coordinate.latitude - center.latitude) <= halfLatitude
            && longitudeDistance <= halfLongitude
    }
}

extension StationPlanner {
    /// Keep the full feed cached, but create annotations only around the camera.
    /// Closed, empty and stale stations still have a place on the map.
    public static func visible(_ snapshot: StationSnapshot, in viewport: MapViewport) -> [Station] {
        let candidates = snapshot.stations.filter { viewport.contains($0.coordinate) }
        var ranked: [NearbyStation] = candidates.map { station in
            NearbyStation(station: station, distance: viewport.center.distance(to: station.coordinate))
        }
        ranked.sort { left, right in
            if left.distance == right.distance { return left.id < right.id }
            return left.distance < right.distance
        }
        return ranked.prefix(30).map(\.station)
    }
}
