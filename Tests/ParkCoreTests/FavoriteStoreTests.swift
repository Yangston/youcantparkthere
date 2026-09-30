import XCTest
@testable import ParkCore

final class FavoriteStoreTests: XCTestCase {
    func testFavoritesSurviveStoreRecreationAndRemoval() {
        let suite = "ParkCoreTests.favorites.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        FavoriteStore(defaults: defaults).save(["7000", "station-not-in-current-feed"])
        let reopened = FavoriteStore(defaults: defaults)
        XCTAssertEqual(reopened.load(), ["7000", "station-not-in-current-feed"])
        var saved = reopened.load()
        saved.remove("7000")
        reopened.save(saved)
        XCTAssertEqual(FavoriteStore(defaults: defaults).load(), ["station-not-in-current-feed"])
    }
    func testExistingPreferenceKeyIsPreserved() {
        let suite = "ParkCoreTests.legacy-favorites.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(["7000", "7000", "7001"], forKey: "favorites")
        XCTAssertEqual(FavoriteStore(defaults: defaults).load(), ["7000", "7001"])
    }
}
