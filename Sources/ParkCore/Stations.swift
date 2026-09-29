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
    public let installed: Bool
    public let renting: Bool
    public let returning: Bool
    public let reportedAt: Date?

    public init(id: String, name: String, coordinate: Coordinate, bikes: Int?, docks: Int?,
                installed: Bool, renting: Bool, returning: Bool, reportedAt: Date?) {
        self.id = id; self.name = name; self.coordinate = coordinate
        self.bikes = bikes; self.docks = docks; self.installed = installed
        self.renting = renting; self.returning = returning; self.reportedAt = reportedAt
    }
    public func count(for mode: SearchMode) -> Int? { mode == .docks ? docks : bikes }
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
public struct RideDetector: Sendable {
    private var cyclingSince: Date?
    private var lastEvidence: Date?
    private var suppressedUntil = Date.distantPast
    public init() {}
    public mutating func observe(cycling: Bool, confident: Bool, conflicting: Bool, at now: Date) {
        lastEvidence = now
        if cycling && confident && !conflicting && now >= suppressedUntil {
            if cyclingSince == nil { cyclingSince = now }
        } else { cyclingSince = nil }
    }
    public func shouldStart(at now: Date) -> Bool {
        guard now >= suppressedUntil, let start = cyclingSince, let evidence = lastEvidence else { return false }
        return now.timeIntervalSince(start) >= 12 && (0...45).contains(now.timeIntervalSince(evidence))
    }
    public mutating func reset() { cyclingSince = nil; lastEvidence = nil }
    public mutating func suppress(at now: Date) {
        reset(); suppressedUntil = now.addingTimeInterval(300)
    }
}

/// Alerts require a *fresh*, previously available target. A network failure is not a full dock.
public struct TargetAvailabilityMonitor: Sendable {
    private var targetID: String?
    private var previousCount: Int?
    public init() {}
    public mutating func update(target: Station?, snapshot: StationSnapshot?, now: Date) -> Bool {
        guard let target, let snapshot else { targetID = nil; previousCount = nil; return false }
        if targetID != target.id { targetID = target.id; previousCount = nil }
        guard let count = snapshot.usableCount(target, mode: .docks, at: now) else {
            previousCount = nil; return false
        }
        defer { previousCount = count }
        return count == 0 && (previousCount ?? 0) > 0
    }
}
