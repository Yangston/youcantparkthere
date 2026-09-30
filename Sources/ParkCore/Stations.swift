import Foundation

public enum SearchMode: String, Codable, CaseIterable, Sendable {
    case docks, bikes
    public var title: String { self == .docks ? "Park" : "Bikes" }
    public var symbol: String { self == .docks ? "parkingsign.circle.fill" : "bicycle" }
}

public struct Coordinate: Codable, Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude; self.longitude = longitude
    }
    public var isValid: Bool {
        latitude.isFinite && longitude.isFinite && abs(latitude) <= 90 && abs(longitude) <= 180
    }
    public func distance(to other: Coordinate) -> Double {
        let r = Double.pi / 180
        let a = pow(sin((other.latitude - latitude) * r / 2), 2)
            + cos(latitude * r) * cos(other.latitude * r)
            * pow(sin((other.longitude - longitude) * r / 2), 2)
        return 6_371_000 * 2 * atan2(sqrt(max(0, min(1, a))), sqrt(max(0, 1 - a)))
    }
    public static let toronto = Coordinate(latitude: 43.6532, longitude: -79.3832)
}

public struct Station: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let coordinate: Coordinate
    public let bikes: Int?
    public let docks: Int?
    public let electricBikes: Int?
    public let standardBikes: Int?
    public let installed: Bool
    public let renting: Bool
    public let returning: Bool
    public let reportedAt: Date?

    public init(id: String, name: String, coordinate: Coordinate, bikes: Int?, docks: Int?,
                installed: Bool, renting: Bool, returning: Bool, reportedAt: Date?, electricBikes: Int? = nil,
                standardBikes: Int? = nil) {
        self.id = id; self.name = name; self.coordinate = coordinate
        self.bikes = bikes; self.docks = docks; self.installed = installed
        self.renting = renting; self.returning = returning; self.reportedAt = reportedAt
        self.electricBikes = electricBikes
        self.standardBikes = standardBikes
    }
    public func count(for mode: SearchMode) -> Int? {
        mode == .docks ? docks : bikes
    }
    public func operational(for mode: SearchMode) -> Bool {
        installed && (mode == .docks ? returning : renting)
    }
}

public struct StationSnapshot: Codable, Equatable, Sendable {
    public let stations: [Station]
    public let updatedAt: Date
    public let fetchedAt: Date
    public let refreshAfter: TimeInterval
    public init(stations: [Station], updatedAt: Date, fetchedAt: Date, refreshAfter: TimeInterval = 30) {
        self.stations = stations; self.updatedAt = updatedAt; self.fetchedAt = fetchedAt
        self.refreshAfter = max(30, refreshAfter)
    }
    public func isFresh(at now: Date) -> Bool {
        (-60...120).contains(now.timeIntervalSince(updatedAt))
            && (-60...120).contains(now.timeIntervalSince(fetchedAt))
    }
    public func isFresh(_ station: Station, at now: Date) -> Bool {
        guard isFresh(at: now), let reported = station.reportedAt else { return false }
        return (-60...300).contains(now.timeIntervalSince(reported))
    }
    public func usableCount(_ station: Station, mode: SearchMode, at now: Date) -> Int? {
        guard isFresh(station, at: now), station.operational(for: mode) else { return nil }
        return station.count(for: mode)
    }
    public func usableElectricCount(_ station: Station, at now: Date) -> Int? {
        guard isFresh(station, at: now), station.operational(for: .bikes) else { return nil }
        return station.electricBikes
    }
    public func usableStandardCount(_ station: Station, at now: Date) -> Int? {
        guard isFresh(station, at: now), station.operational(for: .bikes) else { return nil }
        return station.standardBikes
    }
}

public struct NearbyStation: Identifiable, Sendable {
    public let station: Station
    public let distance: Double
    public var id: String { station.id }
}

public enum StationPlanner {
    public static func nearby(_ snapshot: StationSnapshot, from origin: Coordinate, mode: SearchMode,
                              now: Date, minimum: Int = 1, includeUnavailable: Bool = false,
                              radius: Double = 5_000, limit: Int = 40) -> [NearbyStation] {
        guard origin.isValid, radius > 0, limit > 0 else { return [] }
        return snapshot.stations.compactMap { station -> NearbyStation? in
            let distance = origin.distance(to: station.coordinate)
            guard distance <= radius else { return nil }
            if !includeUnavailable {
                guard let count = snapshot.usableCount(station, mode: mode, at: now),
                      count >= max(1, minimum) else { return nil }
            }
            return NearbyStation(station: station, distance: distance)
        }.sorted {
            $0.distance == $1.distance ? $0.id < $1.id : $0.distance < $1.distance
        }.prefix(limit).map { $0 }
    }
}

/// Only reacts to motion evidence while the app is executing. This does not wake an app.
public struct CyclingDetector: Sendable {
    private var cyclingSince: Date?
    private var nonCyclingSince: Date?
    private var stationaryEvidence = false
    private var lastEvidence: Date?
    private var suppressedUntil = Date.distantPast
    public init() {}
    public mutating func observe(cycling: Bool, confident: Bool, conflicting: Bool, stationary: Bool = false, at now: Date) {
        lastEvidence = now
        if cycling && confident && !conflicting && !stationary && now >= suppressedUntil {
            if cyclingSince == nil { cyclingSince = now }
        } else { cyclingSince = nil }
        if !cycling && confident && (conflicting || stationary) {
            if nonCyclingSince == nil || stationaryEvidence != stationary { nonCyclingSince = now }
            stationaryEvidence = stationary
        } else { nonCyclingSince = nil }
    }
    public func shouldStart(at now: Date) -> Bool {
        guard now >= suppressedUntil, let start = cyclingSince, let evidence = lastEvidence else { return false }
        return now.timeIntervalSince(start) >= 12 && (0...45).contains(now.timeIntervalSince(evidence))
    }
    public func shouldStop(at now: Date) -> Bool {
        guard let since = nonCyclingSince else { return false }
        // Wait longer at a standstill so a normal traffic light does not end navigation.
        return now.timeIntervalSince(since) >= (stationaryEvidence ? 180 : 60)
    }
    public mutating func reset() { cyclingSince = nil; nonCyclingSince = nil; lastEvidence = nil }
    public mutating func suppress(at now: Date) {
        reset(); suppressedUntil = now.addingTimeInterval(300)
    }
}
