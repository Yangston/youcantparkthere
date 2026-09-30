import Foundation
import ParkCore

enum AppPage: String { case map, settings }

enum MapSheet: Identifiable {
    case station(String)
    case privacy
    var id: String {
        switch self {
        case .station(let id): return "station-" + id
        case .privacy: return "privacy"
        }
    }
    var screen: String {
        switch self { case .station: return "detail"; case .privacy: return "privacy" }
    }
}

extension AppModel {
    /// The production widget callback and simulator route checks share this method.
    @discardableResult
    func open(_ url: URL) -> Bool {
        guard let route = AppRoute(url: url) else { return false }
        sheet = nil; page = .map
        switch route {
        case .docks: mode = .docks
        case .bikes: mode = .bikes
        case .ride: mode = .docks // Legacy link now opens the map; it never starts a session.
        }
        return true
    }
}

@MainActor
enum SimulatorSmoke {
    #if DEBUG && targetEnvironment(simulator)
    private static var didRun = false
    #endif

    /// Compiled out of device/release builds. This tests in-app routing, not OS URL delivery.
    static func runIfRequested(model: AppModel) {
        #if DEBUG && targetEnvironment(simulator)
        let args = ProcessInfo.processInfo.arguments
        guard !didRun, model.isDemo, let index = args.firstIndex(of: "--smoke-url"),
              args.indices.contains(index + 1), let url = URL(string: args[index + 1]) else { return }
        didRun = true
        let accepted = model.open(url)
        let report: [String: Any] = [
            "url": url.absoluteString, "accepted": accepted, "demo": model.isDemo,
            "mode": model.mode.rawValue, "cycling": model.cycling, "screen": model.sheet?.screen ?? model.page.rawValue
        ]
        do {
            let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys])
            try data.write(to: folder.appendingPathComponent("simulator-smoke.json"), options: .atomic)
        } catch {
            // The harness requires a valid report; a write failure cannot produce a green check.
            print("Simulator smoke report failed: \(error.localizedDescription)")
        }
        #endif
    }
}
