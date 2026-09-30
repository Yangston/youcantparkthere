import SwiftUI
import ParkCore

/// Development fixtures never activate in a physical-device or Release build.
@MainActor
enum SimulatorPreview {
    static var initialViewport: MapViewport? {
        #if DEBUG && targetEnvironment(simulator)
        return current?.viewport
        #else
        return nil
        #endif
    }
    static var enabled: Bool {
        #if DEBUG && targetEnvironment(simulator)
        return ProcessInfo.processInfo.arguments.contains("--demo") || scenarioID != nil
        #else
        return false
        #endif
    }

    static func configure(_ model: AppModel) {
        #if DEBUG && targetEnvironment(simulator)
        guard enabled else { return }
        do {
            let catalog = try catalog()
            let id = scenarioID ?? "docks"
            guard let scenario = catalog.scenarios.first(where: { $0.id == id }) else {
                throw PreviewError.unknownScenario
            }
            current = scenario
            let date = model.now.addingTimeInterval(-scenario.age)
            let stations: [Station] = scenario.empty == true ? [] : (scenario.stations ?? catalog.stations).map { sample in
                let override = scenario.overrides?[sample.id]
                return Station(id: sample.id, name: sample.name,
                    coordinate: Coordinate(latitude: sample.latitude, longitude: sample.longitude),
                    bikes: sample.bikes, docks: override?.missingDocks == true ? nil : sample.docks,
                    installed: sample.installed, renting: sample.renting,
                    returning: override?.returning ?? sample.returning, reportedAt: date,
                    electricBikes: override?.missingElectricBikes == true ? nil : sample.electricBikes,
                    standardBikes: override?.missingStandardBikes == true ? nil : sample.standardBikes)
            }
            model.snapshot = scenario.data ? StationSnapshot(stations: stations, updatedAt: date, fetchedAt: date) : nil
            model.origin = scenario.gps ? .toronto : nil
            model.locationDate = scenario.gps ? model.now : nil
            model.mode = scenario.mode == "bikes" ? .bikes : .docks
            model.page = scenario.page == "settings" ? .settings : .map
            model.sheet = scenario.page == "detail" ? .station("demo-0") : nil
            model.updateMapViewport(scenario.viewport ?? MapViewport(center: .toronto))
            model.cyclingSince = scenario.cycling ? model.now.addingTimeInterval(-300) : nil
            model.error = scenario.error
            model.favorites = Set(scenario.favorites ?? [])
            // Isolate simulator defaults so previous runs cannot change screenshots.
            UserDefaults.standard.set(scenario.cycling, forKey: "autoDetect")
            model.motionStatus = scenario.cycling ? "Cycling detected (sample)" : "Off (sample)"
            UserDefaults.standard.set(true, forKey: "onboarded")
        } catch {
            model.error = "Preview fixture failed: \(error)"
            // No report is produced; the harness must fail instead of using live data.
            current = nil
        }
        #endif
    }

    static func report(_ model: AppModel) {
        #if DEBUG && targetEnvironment(simulator)
        guard let scenario = current, scenarioID != nil else { return }
        let counts: [Any] = model.snapshot?.stations.map {
            model.freshCount($0).map { $0 as Any } ?? NSNull()
        } ?? []
        let electricCounts: [Any] = model.snapshot?.stations.map {
            model.freshElectricCount($0).map { $0 as Any } ?? NSNull()
        } ?? []
        let standardCounts: [Any] = model.snapshot?.stations.map {
            model.freshStandardCount($0).map { $0 as Any } ?? NSNull()
        } ?? []
        let value: [String: Any] = [
            "scenario": scenario.id, "demo": model.isDemo, "mode": model.mode.rawValue,
            "cycling": model.cycling, "screen": model.sheet?.screen ?? model.page.rawValue, "counts": counts,
            "electricCounts": electricCounts, "standardCounts": standardCounts,
            "favoriteStationIDs": model.favorites.sorted(),
            "visibleStationIDs": model.visibleStations.map(\.id)
        ]
        do {
            let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
                .write(to: folder.appendingPathComponent("preview-state.json"), options: .atomic)
        } catch { print("Preview report failed: \(error.localizedDescription)") }
        #endif
    }

    #if DEBUG && targetEnvironment(simulator)
    static var current: Scenario?
    private enum PreviewError: Error { case unknownScenario }
    private static var scenarioID: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--preview-scenario"), args.indices.contains(index + 1) else { return nil }
        return args[index + 1]
    }
    private static func catalog() throws -> Catalog {
        guard let url = Bundle.main.url(forResource: "fixtures", withExtension: "json") else {
            throw PreviewError.unknownScenario
        }
        return try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url))
    }
    private struct Catalog: Decodable { let stations: [Sample]; let scenarios: [Scenario] }
    struct Sample: Decodable {
        let id: String; let name: String; let latitude: Double; let longitude: Double
        let bikes: Int?; let docks: Int?; let installed: Bool; let renting: Bool; let returning: Bool
        let electricBikes: Int?; let standardBikes: Int?
    }
    struct Scenario: Decodable {
        let id: String; let page: String; let mode: String; let cycling: Bool
        let age: Double; let data: Bool; let gps: Bool
        let favorites: [String]?; let error: String?; let empty: Bool?; let largeText: Bool?
        let overrides: [String: Override]?
        let viewport: MapViewport?
        let stations: [Sample]?
    }
    struct Override: Decodable {
        let returning: Bool?
        let missingDocks: Bool
        let missingStandardBikes: Bool
        let missingElectricBikes: Bool
        enum CodingKeys: String, CodingKey { case returning, docks, electricBikes, standardBikes }
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            returning = try values.decodeIfPresent(Bool.self, forKey: .returning)
            missingDocks = try values.contains(.docks) && values.decodeNil(forKey: .docks)
            missingStandardBikes = try values.contains(.standardBikes) && values.decodeNil(forKey: .standardBikes)
            missingElectricBikes = try values.contains(.electricBikes) && values.decodeNil(forKey: .electricBikes)
        }
    }
    #endif
}

struct PreviewPresentation: ViewModifier {
    #if DEBUG && targetEnvironment(simulator)
    @EnvironmentObject private var model: AppModel
    @State private var presented = false
    #endif
    func body(content: Content) -> some View {
        #if DEBUG && targetEnvironment(simulator)
        if model.isDemo {
          content
            .environment(\.dynamicTypeSize, SimulatorPreview.current?.largeText == true ? .accessibility2 : .large)
            .sheet(isPresented: $presented) {
                if SimulatorPreview.current?.page == "onboarding" {
                    OnboardingView { presented = false }
                }
            }
            .task {
                presented = model.isDemo && SimulatorPreview.current?.page == "onboarding"
            }
        } else { content }
        #else
        content
        #endif
    }
}
