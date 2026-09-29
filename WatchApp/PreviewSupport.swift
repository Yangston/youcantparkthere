import SwiftUI
import ParkCore

/// Development fixtures never activate in a physical-device or Release build.
@MainActor
enum SimulatorPreview {
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
            let stations: [Station] = scenario.empty == true ? [] : catalog.stations.map { sample in
                let override = scenario.overrides?[sample.id]
                return Station(id: sample.id, name: sample.name,
                    coordinate: Coordinate(latitude: sample.latitude, longitude: sample.longitude),
                    bikes: sample.bikes, docks: override?.missingDocks == true ? nil : sample.docks,
                    installed: sample.installed, renting: sample.renting,
                    returning: override?.returning ?? sample.returning, reportedAt: date,
                    electricBikes: override?.missingElectricBikes == true ? nil : sample.electricBikes)
            }
            model.snapshot = scenario.data ? StationSnapshot(stations: stations, updatedAt: date, fetchedAt: date) : nil
            model.origin = scenario.gps ? .toronto : nil
            model.locationDate = scenario.gps ? model.now : nil
            model.mode = scenario.mode == "bikes" ? .bikes : .docks
            model.bikeFilter = scenario.bikeFilter == "electric" ? .electric : .all
            model.sheet = scenario.page == "settings" ? .settings : scenario.page == "detail" ? .station("demo-0") : nil
            model.ridingSince = scenario.riding ? model.now.addingTimeInterval(-300) : nil
            model.targetID = scenario.target
            model.error = scenario.error
            model.favorites = []
            // Isolate simulator defaults so previous runs cannot change screenshots.
            UserDefaults.standard.set(false, forKey: "autoDetect")
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
        let value: [String: Any] = [
            "scenario": scenario.id, "demo": model.isDemo, "mode": model.mode.rawValue,
            "riding": model.riding, "screen": model.sheet?.screen ?? "map", "counts": counts,
            "bikeFilter": model.bikeFilter.rawValue
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
    private struct Sample: Decodable {
        let id: String; let name: String; let latitude: Double; let longitude: Double
        let bikes: Int?; let docks: Int?; let installed: Bool; let renting: Bool; let returning: Bool
        let electricBikes: Int?
    }
    struct Scenario: Decodable {
        let id: String; let page: String; let mode: String; let riding: Bool
        let age: Double; let data: Bool; let gps: Bool
        let target: String?; let error: String?; let empty: Bool?; let largeText: Bool?
        let bikeFilter: String?
        let overrides: [String: Override]?
    }
    struct Override: Decodable {
        let returning: Bool?
        let missingDocks: Bool
        let missingElectricBikes: Bool
        enum CodingKeys: String, CodingKey { case returning, docks, electricBikes }
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            returning = try values.decodeIfPresent(Bool.self, forKey: .returning)
            missingDocks = try values.contains(.docks) && values.decodeNil(forKey: .docks)
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
