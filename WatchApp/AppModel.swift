import SwiftUI
import CoreLocation
import CoreMotion
import WatchKit
import ParkCore

@MainActor
final class AppModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = AppModel()
    @Published var snapshot: StationSnapshot?
    @Published var mode: SearchMode = .docks
    @Published var tab = 0
    @Published var origin: Coordinate?
    @Published var locationDate: Date?
    @Published var now = Date()
    @Published var ridingSince: Date?
    @Published var targetID: String?
    @Published var error: String?
    @Published var fullTarget: String?
    @Published var refreshing = false
    @Published var motionStatus = "Off"
    @Published var locationDenied = false
    @Published var favorites: Set<String> = []
    let isDemo: Bool

    private let client = GBFSClient()
    private let location = CLLocationManager()
    private let motion = CMMotionActivityManager()
    private var detector = RideDetector()
    private var targetMonitor = TargetAvailabilityMonitor()
    private var loop: Task<Void, Never>?
    private var active = false
    private var monitoringMotion = false
    private var pendingRide = false
    private var arrivedTarget: String?
    private var nextRefresh = Date.distantPast
    private var failures = 0

    var riding: Bool { ridingSince != nil }
    var center: Coordinate { origin ?? .toronto }
    var target: Station? { snapshot?.stations.first { $0.id == targetID } }
    var locationLabel: String {
        if isDemo { return "DEMO · sample stations" }
        guard let locationDate else { return "Downtown · no GPS" }
        return now.timeIntervalSince(locationDate) <= 60 ? "Near you" : "Last GPS location"
    }
    var freshnessLabel: String {
        guard let snapshot else { return "No station data" }
        if isDemo { return "DEMO · not live" }
        let seconds = max(0, Int(now.timeIntervalSince(snapshot.updatedAt)))
        if !snapshot.isFresh(at: now) { return "Stale · \(seconds / 60)m old" }
        return "Updated \(seconds)s ago"
    }
    var autoDetect: Bool { UserDefaults.standard.bool(forKey: "autoDetect") }
    private var cacheURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("stations-v1.json")
    }
    override init() {
        isDemo = ProcessInfo.processInfo.arguments.contains("--demo")
        super.init()
        location.delegate = self
        location.activityType = .otherNavigation
        favorites = Set(UserDefaults.standard.stringArray(forKey: "favorites") ?? [])
        if isDemo { loadDemo() }
        else if let url = cacheURL, let data = try? Data(contentsOf: url) {
            snapshot = try? JSONDecoder().decode(StationSnapshot.self, from: data)
        }
    }
    func sceneActive(_ value: Bool) {
        active = value
        now = Date()
        if value { updateAuthorization() }
        configureServices()
    }
    func requestLocation() {
        switch location.authorizationStatus {
        case .notDetermined: location.requestWhenInUseAuthorization()
        case .denied, .restricted:
            error = "Enable location for You Can't Park There in your watch's Privacy & Security settings. Downtown browsing still works."
        default: configureServices()
        }
    }
    func startRide() {
        guard !riding else { mode = .docks; tab = 0; return }
        if !isDemo && location.authorizationStatus == .notDetermined {
            pendingRide = true; requestLocation(); return
        }
        guard isDemo || location.authorizationStatus == .authorizedWhenInUse || location.authorizationStatus == .authorizedAlways else {
            pendingRide = false; requestLocation(); return
        }
        ridingSince = Date(); mode = .docks; tab = 0
        detector.reset()
        WKExtension.shared().isFrontmostTimeoutExtended = true
        WKInterfaceDevice.current().play(.start)
        configureServices()
    }
    func stopRide() {
        ridingSince = nil; pendingRide = false; detector.suppress(at: Date())
        arrivedTarget = nil; targetMonitor = TargetAvailabilityMonitor()
        WKExtension.shared().isFrontmostTimeoutExtended = false
        WKInterfaceDevice.current().play(.stop)
        configureServices()
    }
    func tick() {
        now = Date()
        if autoDetect && !riding && active && detector.shouldStart(at: now) { startRide() }
        if let since = ridingSince, now.timeIntervalSince(since) > 5_400 {
            stopRide(); error = "Ride mode stopped after 90 minutes to save battery. Start it again to continue."
        }
    }
    func settingsChanged() { detector.reset(); configureServices() }
    func toggleFavorite(_ id: String) {
        if favorites.contains(id) { favorites.remove(id) } else { favorites.insert(id) }
        UserDefaults.standard.set(Array(favorites).sorted(), forKey: "favorites")
    }
    func chooseTarget(_ station: Station) {
        targetID = station.id; arrivedTarget = nil
        targetMonitor = TargetAvailabilityMonitor()
        _ = targetMonitor.update(target: station, snapshot: snapshot, now: now)
        tab = 0
    }
    func clearTarget() { targetID = nil; arrivedTarget = nil; targetMonitor = TargetAvailabilityMonitor() }
    func nearby(includeUnavailable: Bool = true, limit: Int = 40) -> [NearbyStation] {
        guard let snapshot else { return [] }
        let minimum = mode == .docks ? max(1, UserDefaults.standard.integer(forKey: "minimumDocks")) : 1
        return StationPlanner.nearby(snapshot, from: center, mode: mode, now: now,
                                     minimum: minimum, includeUnavailable: includeUnavailable, limit: limit)
    }
    func freshCount(_ station: Station, mode: SearchMode? = nil) -> Int? {
        snapshot?.usableCount(station, mode: mode ?? self.mode, at: now)
    }
    func refresh() async {
        guard !refreshing, !isDemo, Date() >= nextRefresh else { return }
        refreshing = true
        defer { refreshing = false }
        do {
            let result = try await client.fetch()
            try Task.checkCancellation()
            snapshot = result; failures = 0; error = nil; now = Date()
            nextRefresh = Date().addingTimeInterval(result.refreshAfter)
            if let url = cacheURL {
                try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                if let data = try? JSONEncoder().encode(result) { try? data.write(to: url, options: .atomic) }
            }
            if riding && targetMonitor.update(target: target, snapshot: result, now: now) {
                fullTarget = "\(target?.name ?? "Your station") is now full. Choose another station."
                WKInterfaceDevice.current().play(.notification)
            }
        } catch is CancellationError { return }
        catch {
            failures += 1
            nextRefresh = Date().addingTimeInterval(min(300, 30 * pow(2, Double(min(failures, 4)))))
            self.error = snapshot == nil ? "Couldn't load stations. \(error.localizedDescription)" : "Offline / feed unavailable. Check the timestamps before riding to a station."
        }
    }
    private func configureServices() {
        let authorized = location.authorizationStatus == .authorizedWhenInUse || location.authorizationStatus == .authorizedAlways
        if !isDemo && authorized && (active || riding) {
            location.desiredAccuracy = riding ? kCLLocationAccuracyNearestTenMeters : kCLLocationAccuracyHundredMeters
            location.distanceFilter = riding ? 20 : 50
            location.allowsBackgroundLocationUpdates = riding
            location.startUpdatingLocation()
        } else { location.stopUpdatingLocation() }
        configureMotion()
        if active || riding {
            if loop == nil {
                loop = Task { [weak self] in
                    while !Task.isCancelled {
                        guard let self else { return }
                        self.tick()
                        await self.refresh()
                        do { try await Task.sleep(nanoseconds: 5_000_000_000) } catch { return }
                    }
                }
            }
        } else {
            loop?.cancel(); loop = nil
        }
    }
    private func configureMotion() {
        guard active && autoDetect && !isDemo else {
            if monitoringMotion { motion.stopActivityUpdates(); monitoringMotion = false; detector.reset() }
            motionStatus = autoDetect ? "Open app to detect" : "Off"
            return
        }
        guard CMMotionActivityManager.isActivityAvailable() else { motionStatus = "Not available on this watch"; return }
        let permission = CMMotionActivityManager.authorizationStatus()
        guard permission != .denied && permission != .restricted else { motionStatus = "Motion permission denied"; return }
        guard !monitoringMotion else { return }
        monitoringMotion = true; motionStatus = "Listening while open"
        motion.startActivityUpdates(to: .main) { [weak self] activity in
            guard let activity else { return }
            let cycling = activity.cycling
            let confident = activity.confidence != .low
            let conflicting = activity.automotive || activity.walking || activity.running || activity.stationary
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.detector.observe(cycling: cycling, confident: confident, conflicting: conflicting, at: Date())
                self.motionStatus = cycling && confident && !conflicting ? "Cycling detected" : "Listening while open"
            }
        }
    }
    private func updateAuthorization() {
        locationDenied = location.authorizationStatus == .denied || location.authorizationStatus == .restricted
        if pendingRide && (location.authorizationStatus == .authorizedAlways || location.authorizationStatus == .authorizedWhenInUse) {
            pendingRide = false; startRide()
        } else if locationDenied { pendingRide = false }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        updateAuthorization(); configureServices()
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let point = locations.last, point.horizontalAccuracy >= 0, point.horizontalAccuracy <= 100,
              abs(point.timestamp.timeIntervalSinceNow) <= 60 else { return }
        origin = Coordinate(latitude: point.coordinate.latitude, longitude: point.coordinate.longitude)
        locationDate = point.timestamp
        if riding, let target, let origin, arrivedTarget != target.id,
           origin.distance(to: target.coordinate) < 60,
           (snapshot?.usableCount(target, mode: .docks, at: Date()) ?? 0) > 0 {
            arrivedTarget = target.id
            WKInterfaceDevice.current().play(.directionUp)
        }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if (error as? CLError)?.code != .locationUnknown { self.error = "GPS unavailable. Distances may use your last position." }
    }
    private func loadDemo() {
        let date = Date()
        origin = .toronto; locationDate = date
        let samples: [(String, Double, Double, Int, Int)] = [
            ("City Hall", 43.6538, -79.3841, 4, 12),
            ("Queen / Bay", 43.6511, -79.3815, 9, 0),
            ("Dundas / University", 43.6546, -79.3890, 6, 3),
            ("Yonge / Dundas", 43.6560, -79.3802, 12, 8)
        ]
        snapshot = StationSnapshot(stations: samples.enumerated().map { index, item in
            Station(id: "demo-\(index)", name: item.0,
                    coordinate: Coordinate(latitude: item.1, longitude: item.2),
                    bikes: item.3, docks: item.4, installed: true, renting: true,
                    returning: true, reportedAt: date)
        }, updatedAt: date, fetchedAt: date)
    }
}
