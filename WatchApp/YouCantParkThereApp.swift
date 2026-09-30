import SwiftUI
import AppIntents
import ParkCore

@main
struct YouCantParkThereWatchApp: App {
    @StateObject private var model = AppModel.shared
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            RootView().modifier(PreviewPresentation()).environmentObject(model)
                .task {
                    model.sceneActive(true)
                    SimulatorSmoke.runIfRequested(model: model)
                    SimulatorPreview.report(model)
                }
                .onChange(of: scenePhase) { _, phase in model.sceneActive(phase == .active) }
                .onOpenURL { url in model.open(url) }
        }
    }
}

struct StartRideIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Bike Share Ride"
    static var description = IntentDescription("Open the dock map and start a user-requested navigation session. Does not unlock a bike.")
    static var openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult {
        AppModel.shared.startRide()
        return .result()
    }
}
struct FindDocksIntent: AppIntent {
    static var title: LocalizedStringResource = "Find Bike Share Docks"
    static var openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult {
        AppModel.shared.mode = .docks; AppModel.shared.sheet = nil; AppModel.shared.page = .map
        return .result()
    }
}
struct ParkingShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: FindDocksIntent(), phrases: ["Find a dock with \(.applicationName)"],
                    shortTitle: "Find docks", systemImageName: "parkingsign.circle")
        AppShortcut(intent: StartRideIntent(), phrases: ["Start a ride with \(.applicationName)"],
                    shortTitle: "Start ride", systemImageName: "bicycle")
    }
}
