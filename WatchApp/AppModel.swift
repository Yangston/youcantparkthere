import SwiftUI
import CoreLocation
import CoreMotion
import WatchKit
import ParkCore
import AppIntents
import RelevanceKit

@MainActor
final class AppModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = AppModel()
    @Published var snapshot: StationSnapshot? { didSet { updateVisibleStations() } }
    @Published var mode: SearchMode = .docks
    @Published var page: AppPage = .map
    @Published var recenterRequest = 0
    @Published var sheet: MapSheet?
    @Published private(set) var visibleStations: [Station] = []
    private(set) var mapViewport = MapViewport(center: .toronto)
    @Published var cyclingSuggestionStatus = "watchOS chooses when to show the shortcut."
    @Published var origin: Coordinate?
    @Published var locationDate: Date?
    @Published var now = Date()
    @Published var cyclingSince: Date?
    @Published var error: String?
    @Published var refreshing = false
    @Published var motionStatus = "Off"
    @Published var locationDenied = false
    @Published var favorites: Set<String> = []
    let isDemo: Bool

    private let client = GBFSClient()
    private let favoriteStore = FavoriteStore()
    private let location = CLLocationManager()
    private let motion = CMMotionActivityManager()
    private var detector = CyclingDetector()
    private var loop: Task<Void, Never>?
    private var active = false
    private var monitoringMotion = false
    private var nextRefresh = Date.distantPast
    private var failures = 0
    private var suggestionUpdate: Task<Void, Never>?

    var cycling: Bool { cyclingSince != nil }
    var center: Coordinate { origin ?? .toronto }
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
    var suggestCycling: Bool { UserDefaults.standard.object(forKey: "suggestRide") as? Bool ?? true }
    private var cacheURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("stations-v1.json")
    }
    override init() {
        isDemo = SimulatorPreview.enabled
        super.init()
        location.delegate = self
        location.activityType = .otherNavigation
        favorites = favoriteStore.load()
        if isDemo { SimulatorPreview.configure(self) }
        else if let url = cacheURL, let data = try? Data(contentsOf: url) {
            snapshot = try? JSONDecoder().decode(StationSnapshot.self, from: data)
        }
    }
    func sceneActive(_ value: Bool) {
        active = value
        guard !isDemo else { return }
        now = Date()
        if value { updateAuthorization() }
        configureServices()
        if value { updateCyclingSuggestion() }
    }
    func requestLocation() {
        guard !isDemo else { return }
        switch location.authorizationStatus {
        case .notDetermined: location.requestWhenInUseAuthorization()
        case .denied, .restricted:
            error = "Enable location for You Can't Park There in your watch's Privacy & Security settings. Downtown browsing still works."
            page = .settings
        default: configureServices()
        }
    }
    private func beginDetectedCycling() {
        guard !cycling, autoDetect else { return }
        cyclingSince = Date(); mode = .docks; page = .map; sheet = nil
        detector.reset()
        WKInterfaceDevice.current().play(.start)
        configureServices()
        updateCyclingSuggestion()
    }
    private func finishDetectedCycling(suppressRestart: Bool = false) {
        cyclingSince = nil
        if suppressRestart { detector.suppress(at: Date()) } else { detector.reset() }
        configureServices()
        updateCyclingSuggestion()
    }
    func tick() {
        guard !isDemo else { return }
        now = Date()
        let permission = CMMotionActivityManager.authorizationStatus()
        if cycling && (!autoDetect || permission == .denied || permission == .restricted) {
            finishDetectedCycling(suppressRestart: true)
            return
        }
        if let since = cyclingSince, now.timeIntervalSince(since) >= 5_400 {
            finishDetectedCycling(suppressRestart: true)
            motionStatus = "Detection paused after 90 minutes."
        } else if cycling && detector.shouldStop(at: now) {
            finishDetectedCycling()
            motionStatus = "Not cycling"
        } else if autoDetect && permission == .authorized && !cycling && active && detector.shouldStart(at: now) {
            beginDetectedCycling()
        }
    }
    func settingsChanged() {
        if !autoDetect {
            // Disabling automatic detection is the immediate stop/opt-out.
            finishDetectedCycling(suppressRestart: true)
        } else {
            detector.reset(); configureServices(); updateCyclingSuggestion()
        }
    }
    func cyclingSuggestionChanged() { updateCyclingSuggestion() }
    private func updateCyclingSuggestion() {
        guard !isDemo else { return }
        let previous = suggestionUpdate
        let start = suggestCycling ? cyclingSince : nil
        // Serialize donations so a delayed detection cannot overwrite a later stop.
        suggestionUpdate = Task { [weak self] in
            await previous?.value
            var intents: [RelevantIntent] = []
            if let start, start.addingTimeInterval(5_400) > Date() {
                intents = [RelevantIntent(RideWidgetConfiguration(), widgetKind: RideWidgetConfiguration.kind,
                    relevance: .date(from: start, to: start.addingTimeInterval(5_400)))]
            }
            do {
                try await RelevantIntentManager.shared.updateRelevantIntents(intents)
                self?.cyclingSuggestionStatus = start == nil
                    ? "Suggested after cycling is detected. watchOS controls placement."
                    : "Cycling shortcut suggested to Smart Stack. watchOS controls placement."
            } catch {
                self?.cyclingSuggestionStatus = "Smart Stack suggestion unavailable. The complication still opens the map."
            }
        }
    }
    func toggleFavorite(_ id: String) {
        if favorites.contains(id) { favorites.remove(id) } else { favorites.insert(id) }
        if !isDemo { favoriteStore.save(favorites) }
    }
    func updateMapViewport(_ viewport: MapViewport) {
        guard viewport.isValid else { return }
        mapViewport = viewport
        updateVisibleStations()
    }
    private func updateVisibleStations() {
        let stations = snapshot.map { StationPlanner.visible($0, in: mapViewport) } ?? []
        // A camera callback with unchanged membership must not rebuild annotations.
        if stations != visibleStations { visibleStations = stations }
    }
    func freshStandardCount(_ station: Station) -> Int? {
        snapshot?.usableStandardCount(station, at: now)
    }
    func freshElectricCount(_ station: Station) -> Int? {
        snapshot?.usableElectricCount(station, at: now)
    }
    func freshCount(_ station: Station, mode: SearchMode? = nil) -> Int? {
        snapshot?.usableCount(station, mode: mode ?? self.mode, at: now)
    }
    func refresh(manual: Bool = false) async {
        // Explicit retries bypass failure backoff. GBFSClient still coalesces
        // requests and respects the feed's successful-response TTL.
        guard !refreshing, !isDemo, manual || Date() >= nextRefresh else { return }
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
        } catch is CancellationError { return }
        catch {
            failures += 1
            nextRefresh = Date().addingTimeInterval(min(300, 30 * pow(2, Double(min(failures, 4)))))
            self.error = snapshot == nil ? "Couldn't load stations. \(error.localizedDescription)" : "Offline / feed unavailable. Check the timestamps before cycling to a station."
        }
    }
    private func configureServices() {
        guard !isDemo else { return }
        let authorized = location.authorizationStatus == .authorizedWhenInUse || location.authorizationStatus == .authorizedAlways
        if !isDemo && authorized && (active || cycling) {
            location.desiredAccuracy = cycling ? kCLLocationAccuracyNearestTenMeters : kCLLocationAccuracyHundredMeters
            location.distanceFilter = cycling ? 20 : 50
            location.allowsBackgroundLocationUpdates = cycling
            location.startUpdatingLocation()
        } else { location.allowsBackgroundLocationUpdates = false; location.stopUpdatingLocation() }
        configureMotion()
        if active || cycling {
            if loop == nil {
                loop = Task { [weak self] in
                    while !Task.isCancelled {
                        guard let self else { return }
                        self.tick()
                        guard !Task.isCancelled else { return }
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
        guard (active || cycling) && autoDetect && !isDemo else {
            if monitoringMotion { motion.stopActivityUpdates(); monitoringMotion = false; detector.reset() }
            motionStatus = autoDetect ? "Open app to detect" : "Off"
            return
        }
        guard CMMotionActivityManager.isActivityAvailable() else { motionStatus = "Not available on this watch"; return }
        let permission = CMMotionActivityManager.authorizationStatus()
        guard permission != .denied && permission != .restricted else {
            motion.stopActivityUpdates(); monitoringMotion = false; detector.reset()
            motionStatus = "Motion permission denied"; return
        }
        guard !monitoringMotion else { return }
        monitoringMotion = true; motionStatus = "Watching for cycling"
        motion.startActivityUpdates(to: .main) { [weak self] activity in
            guard let activity else { return }
            let isCycling = activity.cycling
            let stationary = activity.stationary
            let confident = activity.confidence != .low
            let conflicting = activity.automotive || activity.walking || activity.running || activity.stationary
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.detector.observe(cycling: isCycling, confident: confident, conflicting: conflicting, stationary: stationary, at: Date())
                self.motionStatus = isCycling && confident && !conflicting ? "Cycling detected"
                    : confident && !isCycling && conflicting ? "Not cycling / confirming" : "Activity unclear"
                self.tick()
            }
        }
    }
    private func updateAuthorization() {
        locationDenied = location.authorizationStatus == .denied || location.authorizationStatus == .restricted
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        updateAuthorization(); configureServices()
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let point = locations.last, point.horizontalAccuracy >= 0, point.horizontalAccuracy <= 100,
              abs(point.timestamp.timeIntervalSinceNow) <= 60 else { return }
        origin = Coordinate(latitude: point.coordinate.latitude, longitude: point.coordinate.longitude)
        locationDate = point.timestamp
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if (error as? CLError)?.code != .locationUnknown { self.error = "GPS unavailable. Distances may use your last position." }
    }
}
