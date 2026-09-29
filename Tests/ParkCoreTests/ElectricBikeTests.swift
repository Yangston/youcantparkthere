import XCTest
@testable import ParkCore

final class ElectricBikeTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_000_000)
    func data(_ value: Any) throws -> Data { try JSONSerialization.data(withJSONObject: value) }
    func information() throws -> Data {
        try data(["data": ["stations": [["station_id": "a", "name": "Test", "lat": 43.65, "lon": -79.38]]]])
    }
    func types() throws -> Data {
        try data(["data": ["vehicle_types": [
            ["vehicle_type_id": "manual", "form_factor": "bicycle", "propulsion_type": "human"],
            ["vehicle_type_id": "electric-A", "form_factor": "bicycle", "propulsion_type": "electric_assist"],
            ["vehicle_type_id": "electric-B", "form_factor": "bicycle", "propulsion_type": "electric"],
            ["vehicle_type_id": "scooter", "form_factor": "scooter_standing", "propulsion_type": "electric"]
        ]]] )
    }
    func status(total: Int, rows: [[String: Any]]?) throws -> Data {
        var station: [String: Any] = ["station_id": "a", "num_vehicles_available": total,
            "num_docks_available": 5, "is_installed": true, "is_renting": true,
            "is_returning": true, "last_reported": 1_000_000]
        if let rows { station["vehicle_types_available"] = rows }
        return try data(["last_updated": 1_000_000, "ttl": 30, "data": ["stations": [station]]])
    }
    func row(_ id: String, _ count: Int) -> [String: Any] { ["vehicle_type_id": id, "count": count] }
    func snapshot(total: Int, rows: [[String: Any]]?) throws -> StationSnapshot {
        try GBFSDecoder.snapshot(information: information(), status: status(total: total, rows: rows),
                                 vehicleTypes: types(), now: now)
    }
    func testClassificationIncludesElectricBicyclesAndExcludesScooters() throws {
        let result = try snapshot(total: 9, rows: [row("manual", 3), row("electric-A", 2), row("electric-B", 1), row("scooter", 3)])
        XCTAssertEqual(result.stations[0].bikes, 9)
        XCTAssertEqual(result.stations[0].electricBikes, 3)
    }
    func testOmittedZeroTypesRequireAnExhaustiveBreakdown() throws {
        XCTAssertEqual(try snapshot(total: 4, rows: [row("manual", 2), row("electric-A", 2)]).stations[0].electricBikes, 2)
        XCTAssertNil(try snapshot(total: 5, rows: [row("manual", 2), row("electric-A", 2)]).stations[0].electricBikes)
        XCTAssertEqual(try snapshot(total: 4, rows: [row("manual", 4)]).stations[0].electricBikes, 0)
    }
    func testUnknownDuplicateInvalidAndOvercountedTypesStayUnknown() throws {
        for rows in [[row("new-type", 4)], [row("manual", 2), row("manual", 2)],
                     [row("electric-A", -1)], [row("electric-A", 5)],
                     [row("electric-A", Int.max), row("electric-B", Int.max)]] {
            XCTAssertNil(try snapshot(total: 4, rows: rows).stations[0].electricBikes)
        }
        XCTAssertNil(try snapshot(total: 4, rows: nil).stations[0].electricBikes)
    }
    func testMissingOrMalformedMetadataDoesNotDiscardTotalInventory() throws {
        for metadata in [nil, try data(["data": [:]])] as [Data?] {
            let result = try GBFSDecoder.snapshot(information: information(),
                status: status(total: 4, rows: [row("electric-A", 4)]), vehicleTypes: metadata, now: now)
            XCTAssertEqual(result.stations[0].bikes, 4)
            XCTAssertEqual(result.stations[0].docks, 5)
            XCTAssertNil(result.stations[0].electricBikes)
        }
    }
    func testElectricCountsUseTheSameFreshnessAndOperationGates() throws {
        let result = try snapshot(total: 4, rows: [row("electric-A", 4)])
        let station = result.stations[0]
        XCTAssertEqual(result.usableCount(station, mode: .bikes, at: now, bikeFilter: .electric), 4)
        XCTAssertNil(result.usableCount(station, mode: .bikes, at: now.addingTimeInterval(121), bikeFilter: .electric))
        let closed = Station(id: station.id, name: station.name, coordinate: station.coordinate,
            bikes: 4, docks: 5, installed: true, renting: false, returning: true, reportedAt: now, electricBikes: 4)
        XCTAssertNil(result.usableCount(closed, mode: .bikes, at: now, bikeFilter: .electric))
        XCTAssertEqual(result.usableCount(closed, mode: .docks, at: now, bikeFilter: .electric), 5)
    }
    func testOldCacheWithoutElectricCountsStillDecodes() throws {
        let original = try snapshot(total: 4, rows: [row("electric-A", 4)])
        var encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as! [String: Any]
        var stations = encoded["stations"] as! [[String: Any]]
        stations[0].removeValue(forKey: "electricBikes"); encoded["stations"] = stations
        let restored = try JSONDecoder().decode(StationSnapshot.self, from: data(encoded))
        XCTAssertNil(restored.stations[0].electricBikes)
        XCTAssertEqual(restored.stations[0].bikes, 4)
    }
    func testOptionalMetadataFailurePreservesStationDataAndBacksOff() async throws {
        let discovery = try data(["data": ["feeds": [
            ["name": "station_information", "url": "https://example.com/info"],
            ["name": "station_status", "url": "https://example.com/status"],
            ["name": "vehicle_types", "url": "https://example.com/types"]]]])
        let transport = TypeFailureTransport(payloads: ["/gbfs": discovery, "/info": try information(),
            "/status": try status(total: 4, rows: [row("electric-A", 4)])])
        let client = GBFSClient(discoveryURL: URL(string: "https://example.com/gbfs")!, transport: transport)
        let first = try await client.fetch(now: now)
        XCTAssertEqual(first.stations[0].bikes, 4); XCTAssertNil(first.stations[0].electricBikes)
        _ = try await client.fetch(now: now.addingTimeInterval(31))
        let requests = await transport.typeRequests
        XCTAssertEqual(requests, 1)
    }
}

private actor TypeFailureTransport: FeedTransport {
    let payloads: [String: Data]
    var typeRequests = 0
    init(payloads: [String: Data]) { self.payloads = payloads }
    func load(_ url: URL) async throws -> Data {
        if url.path == "/types" { typeRequests += 1; throw FeedError.http(503) }
        guard let data = payloads[url.path] else { throw FeedError.http(404) }
        return data
    }
}
