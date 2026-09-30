import XCTest
@testable import ParkCore

final class ParkCoreTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_790_704_800)
    func json(_ value: Any) throws -> Data { try JSONSerialization.data(withJSONObject: value) }
    func information(name: Any = "Bay / Queen", id: Any = "7000", lat: Double = 43.6532) throws -> Data {
        try json(["data": ["stations": [["station_id": id, "name": name, "lat": lat, "lon": -79.3832]]]])
    }
    func status(docks: Any = 4, bikesKey: String = "num_bikes_available", returning: Any = 1,
                reported: Any? = nil, updated: Any? = nil, ttl: Int = 30) throws -> Data {
        try json(["last_updated": updated ?? now.timeIntervalSince1970, "ttl": ttl,
                  "data": ["stations": [["station_id": "7000", bikesKey: 7, "num_docks_available": docks,
                                          "is_installed": 1, "is_renting": 1, "is_returning": returning,
                                          "last_reported": reported ?? now.timeIntervalSince1970]]]])
    }
    func fixture(docks: Int = 4, returning: Bool = true) throws -> StationSnapshot {
        try GBFSDecoder.snapshot(information: information(), status: status(docks: docks, returning: returning), now: now)
    }
    func testDecodesLegacyNumericFlagsAndTimestamp() throws {
        let result = try fixture()
        XCTAssertEqual(result.stations.first?.bikes, 7)
        XCTAssertEqual(result.stations.first?.docks, 4)
        XCTAssertEqual(result.updatedAt, now)
        XCTAssertTrue(result.stations[0].returning)
    }
    func testDecodesV3LocalizedNamesVehiclesAndISODates() throws {
        let iso = ISO8601DateFormatter().string(from: now)
        let result = try GBFSDecoder.snapshot(
            information: information(name: [["language": "fr", "text": "Français"], ["language": "en", "text": "English station"]]),
            status: status(bikesKey: "num_vehicles_available", returning: true, reported: iso, updated: iso), now: now)
        XCTAssertEqual(result.stations[0].name, "English station")
        XCTAssertEqual(result.stations[0].bikes, 7)
        XCTAssertTrue(result.isFresh(at: now))
    }
    func testFractionalISOAndNumericStationID() throws {
        let result = try GBFSDecoder.snapshot(information: information(id: 7000),
            status: status(reported: "2026-09-29T12:40:00.123Z", updated: "2026-09-29T12:40:00.123Z"), now: now)
        XCTAssertEqual(result.stations[0].id, "7000")
        XCTAssertNotNil(result.stations[0].reportedAt)
    }
    func testClosedStationExcludedEvenWithFreeDocks() throws {
        let result = try fixture(returning: false)
        XCTAssertTrue(StationPlanner.nearby(result, from: .toronto, mode: .docks, now: now).isEmpty)
        XCTAssertEqual(StationPlanner.nearby(result, from: .toronto, mode: .bikes, now: now).count, 1)
    }
    func testFullStationExcluded() throws {
        let result = try fixture(docks: 0)
        XCTAssertTrue(StationPlanner.nearby(result, from: .toronto, mode: .docks, now: now).isEmpty)
    }
    func testUnavailableToggleRetainsFullStations() throws {
        let result = try fixture(docks: 0)
        XCTAssertEqual(StationPlanner.nearby(result, from: .toronto, mode: .docks, now: now, includeUnavailable: true).count, 1)
    }
    func testMinimumDocksFilter() throws {
        XCTAssertTrue(StationPlanner.nearby(try fixture(docks: 2), from: .toronto, mode: .docks, now: now, minimum: 3).isEmpty)
    }
    func testStalePublicationNeverAdvertisedAsAvailable() throws {
        let result = try fixture()
        XCTAssertNil(result.usableCount(result.stations[0], mode: .docks, at: now.addingTimeInterval(121)))
    }
    func testStaleStationNeverAdvertisedAsAvailable() throws {
        let result = try GBFSDecoder.snapshot(information: information(), status: status(reported: now.addingTimeInterval(-301).timeIntervalSince1970), now: now)
        XCTAssertTrue(result.isFresh(at: now))
        XCTAssertNil(result.usableCount(result.stations[0], mode: .docks, at: now))
    }
    func testFutureFeedTimestampIsNotFresh() throws {
        let result = try GBFSDecoder.snapshot(information: information(), status: status(updated: now.addingTimeInterval(600).timeIntervalSince1970), now: now)
        XCTAssertFalse(result.isFresh(at: now))
    }
    func testMissingStatusFlagsFailClosed() throws {
        let partial = try json(["last_updated": now.timeIntervalSince1970,
                                "data": ["stations": [["station_id": "7000", "num_docks_available": 10]]]])
        let result = try GBFSDecoder.snapshot(information: information(), status: partial, now: now)
        XCTAssertFalse(result.stations[0].returning)
        XCTAssertNil(result.stations[0].bikes)
        XCTAssertNil(result.usableCount(result.stations[0], mode: .docks, at: now))
    }
    func testNegativeInventoryRemainsUnknown() throws {
        let result = try GBFSDecoder.snapshot(information: information(), status: status(docks: -2), now: now)
        XCTAssertNil(result.stations[0].docks)
    }
    func testInvalidCoordinateRejected() throws {
        XCTAssertThrowsError(try GBFSDecoder.snapshot(information: information(lat: 300), status: status(), now: now))
    }
    func testMalformedFeedThrows() throws {
        XCTAssertThrowsError(try GBFSDecoder.snapshot(information: Data("no".utf8), status: status()))
        XCTAssertThrowsError(try GBFSDecoder.snapshot(information: information(), status: json(["data": ["stations": []]])))
    }
    func testDistanceAndRange() throws {
        XCTAssertEqual(Coordinate.toronto.distance(to: .toronto), 0, accuracy: 0.001)
        XCTAssertEqual(Coordinate(latitude: 0, longitude: 0).distance(to: Coordinate(latitude: 0, longitude: 1)), 111_195, accuracy: 1)
        XCTAssertTrue(StationPlanner.nearby(try fixture(), from: Coordinate(latitude: 0, longitude: 0), mode: .docks, now: now).isEmpty)
    }
    func testRadiusAndLimitDoNotCrashOnBadInput() throws {
        XCTAssertTrue(StationPlanner.nearby(try fixture(), from: .toronto, mode: .docks, now: now, limit: -1).isEmpty)
    }
    func testDiscoveryV1AndV3() throws {
        let feeds = [["name": "station_information", "url": "https://example.com/info"], ["name": "station_status", "url": "https://example.com/status"]]
        XCTAssertEqual(try GBFSDecoder.discover(json(["data": ["feeds": feeds]])).count, 2)
        XCTAssertEqual(try GBFSDecoder.discover(json(["data": ["en": ["feeds": feeds]]])).count, 2)
    }
    func testInsecureDiscoveryRejected() throws {
        let feeds = [["name": "station_information", "url": "http://example.com/info"], ["name": "station_status", "url": "https://example.com/status"]]
        XCTAssertThrowsError(try GBFSDecoder.discover(json(["data": ["feeds": feeds]])))
    }
    func testCacheRoundTripPreservesTimestamps() throws {
        let original = try fixture()
        XCTAssertEqual(try JSONDecoder().decode(StationSnapshot.self, from: JSONEncoder().encode(original)), original)
    }
    func testCyclingRequiresSustainedConfidentEvidence() {
        var detector = CyclingDetector()
        detector.observe(cycling: true, confident: true, conflicting: false, at: now)
        XCTAssertFalse(detector.shouldStart(at: now.addingTimeInterval(11)))
        XCTAssertTrue(detector.shouldStart(at: now.addingTimeInterval(12)))
        XCTAssertFalse(detector.shouldStart(at: now.addingTimeInterval(46)))
    }
    func testDrivingAndLowConfidenceDoNotStartRide() {
        var detector = CyclingDetector()
        detector.observe(cycling: true, confident: true, conflicting: true, at: now)
        XCTAssertFalse(detector.shouldStart(at: now.addingTimeInterval(20)))
        detector.observe(cycling: true, confident: false, conflicting: false, at: now)
        XCTAssertFalse(detector.shouldStart(at: now.addingTimeInterval(20)))
    }
    func testEndRideSuppressesAutomaticRestart() {
        var detector = CyclingDetector()
        detector.suppress(at: now)
        detector.observe(cycling: true, confident: true, conflicting: false, at: now.addingTimeInterval(10))
        XCTAssertFalse(detector.shouldStart(at: now.addingTimeInterval(30)))
        detector.observe(cycling: true, confident: true, conflicting: false, at: now.addingTimeInterval(301))
        XCTAssertTrue(detector.shouldStart(at: now.addingTimeInterval(314)))
    }
    func testTTLHasMinimumButRespectsLongServerTTL() throws {
        let result = try GBFSDecoder.snapshot(information: information(), status: status(ttl: 180), now: now)
        XCTAssertEqual(result.refreshAfter, 180)
        XCTAssertEqual(try fixture().refreshAfter, 30)
    }
    func testClientCachesInformationAndRespectsStatusTTL() async throws {
        let base = URL(string: "https://example.com/gbfs")!
        let discovery = try json(["data": ["feeds": [["name": "station_information", "url": "https://example.com/info"], ["name": "station_status", "url": "https://example.com/status"]]]])
        let transport = FakeTransport(payloads: ["/gbfs": discovery, "/info": try information(), "/status": try status()])
        let client = GBFSClient(discoveryURL: base, transport: transport)
        _ = try await client.fetch(now: now)
        _ = try await client.fetch(now: now.addingTimeInterval(5))
        let firstCalls = await transport.calls
        XCTAssertEqual(firstCalls, 3)
        _ = try await client.fetch(now: now.addingTimeInterval(31))
        let nextCalls = await transport.calls
        XCTAssertEqual(nextCalls, 4)
    }
    func testClientRejectsUntrustedFeedHost() async throws {
        let discovery = try json(["data": ["feeds": [["name": "station_information", "url": "https://evil.example/info"], ["name": "station_status", "url": "https://evil.example/status"]]]])
        let client = GBFSClient(discoveryURL: URL(string: "https://example.com/gbfs")!, transport: FakeTransport(payloads: ["/gbfs": discovery]))
        do { _ = try await client.fetch(); XCTFail("Should reject host") } catch { XCTAssertTrue(error is FeedError) }
    }
}

actor FakeTransport: FeedTransport {
    let payloads: [String: Data]
    private(set) var calls = 0
    init(payloads: [String: Data]) { self.payloads = payloads }
    func load(_ url: URL) async throws -> Data {
        calls += 1
        guard let data = payloads[url.path] else { throw FeedError.http(404) }
        return data
    }
}
