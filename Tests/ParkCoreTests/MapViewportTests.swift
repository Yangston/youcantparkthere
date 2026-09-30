import XCTest
@testable import ParkCore

final class MapViewportTests: XCTestCase {
    private func station(_ id: String, _ coordinate: Coordinate) -> Station {
        Station(id: id, name: id, coordinate: coordinate, bikes: nil, docks: 0,
                installed: false, renting: false, returning: false, reportedAt: nil)
    }
    private func snapshot(_ stations: [Station]) -> StationSnapshot {
        StationSnapshot(stations: stations, updatedAt: .distantPast, fetchedAt: .distantPast)
    }

    func testPanningUsesCameraInsteadOfGPSAndCapsAtThirtyStations() {
        let remote = Coordinate(latitude: 43.75, longitude: -79.4)
        XCTAssertGreaterThan(remote.distance(to: .toronto), 5_000)
        let stations = [station("home", .toronto)] + (0..<60).map { station("remote-\($0)", remote) }
        let feed = snapshot(stations)
        XCTAssertEqual(StationPlanner.visible(feed, in: MapViewport(center: .toronto)).map(\.id), ["home"])
        let visible = StationPlanner.visible(feed, in: MapViewport(center: remote))
        XCTAssertEqual(visible.count, 30)
        XCTAssertEqual(visible.map(\.id), (0..<60).map { "remote-\($0)" }.sorted().prefix(30).map { $0 })
        XCTAssertFalse(visible.contains { $0.id == "home" })
        // Moving back restores cached stations, including unknown/closed inventory.
        XCTAssertEqual(StationPlanner.visible(feed, in: MapViewport(center: .toronto)).map(\.id), ["home"])
        XCTAssertEqual(feed.stations.count, 61)
    }

    func testNearestThirtyChangeWithCameraCenterRegardlessOfFeedOrder() {
        let stations = (0..<60).map { index in
            station(String(format: "%02d", index), Coordinate(latitude: Double(index) * 0.0001, longitude: 0))
        }
        let feed = snapshot(Array(stations.reversed()))
        let left = MapViewport(center: Coordinate(latitude: 0, longitude: 0), latitudeSpan: 0.02, longitudeSpan: 0.02)
        let right = MapViewport(center: Coordinate(latitude: 0.0059, longitude: 0), latitudeSpan: 0.02, longitudeSpan: 0.02)
        XCTAssertEqual(StationPlanner.visible(feed, in: left).map(\.id), Array(stations.prefix(30)).map(\.id))
        XCTAssertEqual(Set(StationPlanner.visible(feed, in: right).map(\.id)), Set(stations.suffix(30).map(\.id)))
    }

    func testOverscanAndCullingAtViewportBoundary() {
        let viewport = MapViewport(center: Coordinate(latitude: 0, longitude: 0), latitudeSpan: 2, longitudeSpan: 2)
        XCTAssertTrue(viewport.contains(Coordinate(latitude: 1.1, longitude: 1.1)))
        XCTAssertFalse(viewport.contains(Coordinate(latitude: 1.3, longitude: 0)))
        XCTAssertFalse(viewport.contains(Coordinate(latitude: 0, longitude: -1.3)))
        XCTAssertFalse(viewport.contains(Coordinate(latitude: 1.1, longitude: 0), overscan: 0))
    }

    func testLongitudeWrapsAcrossDateLine() {
        let viewport = MapViewport(center: Coordinate(latitude: 0, longitude: 179.8), latitudeSpan: 2, longitudeSpan: 2)
        XCTAssertTrue(viewport.contains(Coordinate(latitude: 0, longitude: -179.8)))
        XCTAssertFalse(viewport.contains(Coordinate(latitude: 0, longitude: -175)))
        XCTAssertTrue(MapViewport(center: .toronto, latitudeSpan: 180, longitudeSpan: 360)
            .contains(Coordinate(latitude: 0, longitude: 100)))
    }

    func testInvalidBoundsAndCoordinatesDoNotRenderStations() {
        for span in [Double.nan, .infinity, 0, -1] {
            XCTAssertFalse(MapViewport(center: .toronto, latitudeSpan: span).contains(.toronto))
            XCTAssertFalse(MapViewport(center: .toronto, longitudeSpan: span).contains(.toronto))
        }
        XCTAssertFalse(MapViewport(center: Coordinate(latitude: 100, longitude: 0)).contains(.toronto))
        XCTAssertFalse(MapViewport(center: .toronto).contains(Coordinate(latitude: .nan, longitude: 0)))
    }
}
