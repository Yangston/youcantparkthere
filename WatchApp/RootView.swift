import SwiftUI
import ParkCore

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("onboarded") private var onboarded = false
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    var body: some View {
        TabView(selection: $model.tab) {
            DockMapView().tag(0)
            NearbyView().tag(1)
            RideSettingsView().tag(2)
        }
        .tabViewStyle(.page)
        .tint(.orange)
        .onReceive(timer) { _ in model.tick() }
        .sheet(isPresented: Binding(get: { !onboarded && !model.isDemo }, set: { onboarded = !$0 })) {
            OnboardingView { onboarded = true }
        }
        .alert("That station is full", isPresented: Binding(get: { model.fullTarget != nil }, set: { if !$0 { model.fullTarget = nil } })) {
            Button("Find another") { model.clearTarget(); model.mode = .docks; model.tab = 1 }
            Button("Dismiss", role: .cancel) { model.fullTarget = nil }
        } message: { Text(model.fullTarget ?? "") }
    }
}
