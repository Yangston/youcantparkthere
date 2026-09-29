import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum FeedError: LocalizedError {
    case invalid(String)
    case http(Int)
    public var errorDescription: String? {
        switch self {
        case .invalid(let detail): return "Bike Share data: \(detail)"
        case .http(let code): return "Bike Share server returned HTTP \(code)."
        }
    }
}

/// Decodes GBFS 1/2 numeric timestamps and GBFS 3 ISO timestamps/localized station names.
/// Missing status flags fail closed; missing inventory stays unknown rather than becoming zero.
public enum GBFSDecoder {
    static func object(_ data: Data) throws -> [String: Any] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FeedError.invalid("Expected a JSON object.")
        }
        return root
    }
    static func body(_ root: [String: Any]) throws -> [String: Any] {
        guard let data = root["data"] as? [String: Any] else { throw FeedError.invalid("Missing data.") }
        return data
    }
    static func text(_ value: Any?) -> String? {
        if let value = value as? String { return value }
        if let value = value as? NSNumber { return value.stringValue }
        return nil
    }
    static func integer(_ value: Any?) -> Int? {
        guard let text = text(value), let value = Int(text), value >= 0 else { return nil }
        return value
    }
    static func flag(_ value: Any?) -> Bool {
        if let number = value as? NSNumber { return number.intValue == 1 }
        return (value as? String).map { $0 == "1" || $0.lowercased() == "true" } ?? false
    }
    static func date(_ value: Any?) -> Date? {
        if let number = value as? NSNumber, number.doubleValue.isFinite, number.doubleValue > 0, number.doubleValue <= 253_402_300_799 {
            return Date(timeIntervalSince1970: number.doubleValue)
        }
        guard let text = value as? String else { return nil }
        if let seconds = Double(text), seconds.isFinite, seconds > 0, seconds <= 253_402_300_799 { return Date(timeIntervalSince1970: seconds) }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: text)
    }
    static func name(_ value: Any?) -> String? {
        if let text = value as? String { return text }
        guard let values = value as? [[String: Any]] else { return nil }
        return (values.first { ($0["language"] as? String)?.hasPrefix("en") == true } ?? values.first)?["text"] as? String
    }
    public static func discover(_ data: Data) throws -> [String: URL] {
        let body = try body(object(data))
        let language = (body["en"] as? [String: Any]) ?? body.values.compactMap { $0 as? [String: Any] }.first
        guard let feeds = (body["feeds"] ?? language?["feeds"]) as? [[String: Any]] else {
            throw FeedError.invalid("No discovery feeds.")
        }
        var result: [String: URL] = [:]
        for feed in feeds {
            if let name = feed["name"] as? String, let path = feed["url"] as? String,
               let url = URL(string: path), url.scheme == "https" { result[name] = url }
        }
        guard result["station_information"] != nil, result["station_status"] != nil else {
            throw FeedError.invalid("Station feeds missing or not HTTPS.")
        }
        return result
    }
    public static func snapshot(information: Data, status: Data, now: Date = Date()) throws -> StationSnapshot {
        let infoRoot = try object(information), statusRoot = try object(status)
        guard let infos = try body(infoRoot)["stations"] as? [[String: Any]],
              let statuses = try body(statusRoot)["stations"] as? [[String: Any]],
              let updated = date(statusRoot["last_updated"]) else {
            throw FeedError.invalid("Missing stations or publication timestamp.")
        }
        var lookup: [String: [String: Any]] = [:]
        for status in statuses { if let id = text(status["station_id"]) { lookup[id] = status } }
        var seen = Set<String>()
        let stations: [Station] = infos.compactMap { info in
            guard let id = text(info["station_id"]), seen.insert(id).inserted,
                  let name = name(info["name"]), !name.isEmpty,
                  let latitude = info["lat"] as? Double, let longitude = info["lon"] as? Double else { return nil }
            let point = Coordinate(latitude: latitude, longitude: longitude)
            guard point.isValid else { return nil }
            let status = lookup[id] ?? [:]
            return Station(id: id, name: name, coordinate: point,
                           bikes: integer(status["num_vehicles_available"] ?? status["num_bikes_available"]),
                           docks: integer(status["num_docks_available"]),
                           installed: flag(status["is_installed"]), renting: flag(status["is_renting"]),
                           returning: flag(status["is_returning"]), reportedAt: date(status["last_reported"]))
        }
        guard !stations.isEmpty else { throw FeedError.invalid("No valid stations.") }
        return StationSnapshot(stations: stations, updatedAt: updated, fetchedAt: now,
                               refreshAfter: TimeInterval(integer(statusRoot["ttl"]) ?? 30))
    }
}

public protocol FeedTransport: Sendable {
    func load(_ url: URL) async throws -> Data
}
public struct URLSessionFeedTransport: FeedTransport {
    public init() {}
    public func load(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FeedError.invalid("Not an HTTP response.") }
        guard (200...299).contains(http.statusCode) else { throw FeedError.http(http.statusCode) }
        guard http.url?.scheme == "https", data.count <= 8_000_000 else { throw FeedError.invalid("Invalid response.") }
        return data
    }
}

public actor GBFSClient {
    public static let torontoURL = URL(string: "https://toronto.publicbikesystem.net/customer/gbfs/v3.0/gbfs.json")!
    private let discoveryURL: URL
    private let transport: any FeedTransport
    private var feeds: [String: URL] = [:]
    private var information: Data?
    private var infoExpiry = Date.distantPast
    private var cached: StationSnapshot?
    private var nextRequest = Date.distantPast
    private var inFlight: Task<StationSnapshot, Error>?
    public init(discoveryURL: URL = GBFSClient.torontoURL, transport: any FeedTransport = URLSessionFeedTransport()) {
        self.discoveryURL = discoveryURL; self.transport = transport
    }
    public func fetch(now: Date = Date()) async throws -> StationSnapshot {
        if let cached, now < nextRequest { return cached }
        if let inFlight { return try await inFlight.value }
        let task = Task { try await self.performFetch(now: now) }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }
    private func performFetch(now: Date) async throws -> StationSnapshot {
        do {
            if information == nil || now >= infoExpiry {
                feeds = try GBFSDecoder.discover(await transport.load(discoveryURL))
                // Trust only the configured operator host, not arbitrary URLs in a feed.
                guard feeds.values.allSatisfy({ $0.host == discoveryURL.host && $0.scheme == "https" }),
                      let infoURL = feeds["station_information"] else { throw FeedError.invalid("Unexpected feed host.") }
                information = try await transport.load(infoURL)
                infoExpiry = now.addingTimeInterval(21_600)
            }
            guard let information, let statusURL = feeds["station_status"] else { throw FeedError.invalid("Discovery incomplete.") }
            let status = try await transport.load(statusURL)
            let snapshot = try GBFSDecoder.snapshot(information: information, status: status, now: now)
            cached = snapshot
            nextRequest = now.addingTimeInterval(snapshot.refreshAfter)
            return snapshot
        } catch {
            infoExpiry = .distantPast
            throw error
        }
    }
}
