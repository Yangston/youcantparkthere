import SwiftUI
import ParkCore

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("onboarded") private var onboarded = false
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ZStack {
                    if model.page == .map {
                        DockMapView().transition(.move(edge: .leading))
                    } else {
                        RideSettingsView()
                            .padding(.top, max(geometry.safeAreaInsets.top, geometry.size.height * 0.14))
                            .simultaneousGesture(pageSwipe)
                            .transition(.move(edge: .trailing))
                    }
                }
                .frame(width: geometry.size.width, height: max(0, geometry.size.height - 56))
                .clipped().contentShape(Rectangle())
                // A separate sibling, not an overlay on MapKit: map pan recognizers
                // cannot receive touches that begin in the controls or page dots.
                BottomNavigationView().frame(height: 56)
                    .contentShape(Rectangle()).highPriorityGesture(pageSwipe)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: model.page)
        }
        .ignoresSafeArea()
        .background(.black)
        .tint(.orange)
        .onReceive(timer) { _ in model.tick() }
        .sheet(item: $model.sheet) { sheet in
            switch sheet {
            case .station(let id): StationDetailView(stationID: id)
            }
        }
        .sheet(isPresented: Binding(get: { !onboarded && !model.isDemo }, set: { onboarded = !$0 })) {
            OnboardingView { onboarded = true }
        }
        .alert("That station is full", isPresented: Binding(get: { model.fullTarget != nil }, set: { if !$0 { model.fullTarget = nil } })) {
            Button("Find another") { model.clearTarget(); model.mode = .docks; model.sheet = nil; model.page = .map }
            Button("Dismiss", role: .cancel) { model.fullTarget = nil }
        } message: { Text(model.fullTarget ?? "") }
    }

    private var pageSwipe: some Gesture {
        DragGesture(minimumDistance: 12).onEnded { value in
            guard abs(value.translation.width) >= 30,
                  abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
            model.page = value.translation.width < 0 ? .settings : .map
        }
    }
}
