import SwiftUI
import ParkCore

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("onboarded") private var onboarded = false
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    var body: some View {
        DockMapView()
        .tint(.orange)
        .onReceive(timer) { _ in model.tick() }
        .sheet(item: $model.sheet) { sheet in
            switch sheet {
            case .settings: RideSettingsView()
            case .station(let id): StationDetailView(stationID: id)
            }
        }
        .sheet(isPresented: Binding(get: { !onboarded && !model.isDemo }, set: { onboarded = !$0 })) {
            OnboardingView { onboarded = true }
        }
        .alert("That station is full", isPresented: Binding(get: { model.fullTarget != nil }, set: { if !$0 { model.fullTarget = nil } })) {
            Button("Find another") { model.clearTarget(); model.mode = .docks; model.sheet = nil }
            Button("Dismiss", role: .cancel) { model.fullTarget = nil }
        } message: { Text(model.fullTarget ?? "") }
    }
}
