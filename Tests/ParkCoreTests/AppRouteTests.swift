import Foundation
import XCTest
@testable import ParkCore

final class AppRouteTests: XCTestCase {
    func testEveryWidgetRoute() {
        for route in AppRoute.allCases {
            XCTAssertEqual(AppRoute(url: URL(string: "youcantparkthere://\(route.rawValue)")!), route)
        }
    }
    func testTrailingSlash() {
        XCTAssertEqual(AppRoute(url: URL(string: "youcantparkthere://bikes/")!), .bikes)
    }
    func testUnknownSchemeAndDestinationAreIgnored() {
        for value in ["https://bikes", "youcantparkthere://unknown", "youcantparkthere://", "youcantparkthere:///ride"] {
            XCTAssertNil(AppRoute(url: URL(string: value)!), value)
        }
    }
    func testUnexpectedURLComponentsAreIgnored() {
        for value in ["youcantparkthere://user@ride", "youcantparkthere://ride:80", "youcantparkthere://ride/other", "youcantparkthere://ride?start=true", "youcantparkthere://ride#other"] {
            XCTAssertNil(AppRoute(url: URL(string: value)!), value)
        }
    }
}
