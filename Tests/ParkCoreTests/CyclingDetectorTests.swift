import XCTest
@testable import ParkCore

final class CyclingDetectorTests: XCTestCase {
    let start = Date(timeIntervalSince1970: 1_790_704_800)

    func testStationaryStopWaitsThroughShortTrafficLightAndCyclingCancelsIt() {
        var detector = CyclingDetector()
        detector.observe(cycling: false, confident: true, conflicting: false, stationary: true, at: start)
        XCTAssertFalse(detector.shouldStop(at: start.addingTimeInterval(90)))
        XCTAssertTrue(detector.shouldStop(at: start.addingTimeInterval(180)))
        detector.observe(cycling: true, confident: true, conflicting: false, at: start.addingTimeInterval(181))
        XCTAssertFalse(detector.shouldStop(at: start.addingTimeInterval(300)))
    }

    func testSustainedWalkingOrDrivingStopsButUnknownDoesNotPretendToBeStopped() {
        var detector = CyclingDetector()
        detector.observe(cycling: false, confident: true, conflicting: true, at: start)
        XCTAssertFalse(detector.shouldStop(at: start.addingTimeInterval(59)))
        XCTAssertTrue(detector.shouldStop(at: start.addingTimeInterval(60)))
        detector.observe(cycling: false, confident: false, conflicting: false, at: start.addingTimeInterval(61))
        XCTAssertFalse(detector.shouldStop(at: start.addingTimeInterval(500)))
    }

    func testConflictingCyclingDoesNotTriggerEitherTransition() {
        var detector = CyclingDetector()
        detector.observe(cycling: true, confident: true, conflicting: true, at: start)
        XCTAssertFalse(detector.shouldStart(at: start.addingTimeInterval(12)))
        XCTAssertFalse(detector.shouldStop(at: start.addingTimeInterval(200)))
    }

    func testChangingStopClassificationRequiresNewQualification() {
        var detector = CyclingDetector()
        detector.observe(cycling: false, confident: true, conflicting: false, stationary: true, at: start)
        detector.observe(cycling: false, confident: true, conflicting: true, at: start.addingTimeInterval(170))
        XCTAssertFalse(detector.shouldStop(at: start.addingTimeInterval(180)))
        XCTAssertTrue(detector.shouldStop(at: start.addingTimeInterval(230)))
    }
}
