import SwiftUI
import ParkCore

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("onboarded") private var onboarded = false
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                if model.page == .map {
                    DockMapView()
                        // Tell MapKit to keep attribution above the controls while
                        // its map background extends through their safe area.
                        .safeAreaPadding(.bottom, 56)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .contentShape(.interaction, MapPanArea(bottomInset: 56))
                        .transition(.move(edge: .leading))
                } else {
                    RideSettingsView()
                        .padding(.top, max(geometry.safeAreaInsets.top, geometry.size.height * 0.14))
                        .frame(width: geometry.size.width, height: max(0, geometry.size.height - 56))
                        .clipped().contentShape(Rectangle())
                        .simultaneousGesture(pageSwipe)
                        .frame(height: geometry.size.height, alignment: .top)
                        .transition(.move(edge: .trailing))
                }
                // This transparent sibling owns the same bottom touch area.
                // Its background is the live map, not a separately painted bar.
                BottomNavigationView().frame(height: 56)
                    .background(Color.clear.contentShape(Rectangle()))
                    .contentShape(Rectangle()).highPriorityGesture(pageSwipe)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
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

    }

    private var pageSwipe: some Gesture {
        DragGesture(minimumDistance: 12).onEnded { value in
            guard abs(value.translation.width) >= 30,
                  abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
            model.page = value.translation.width < 0 ? .settings : .map
        }
    }
}

/// A map can draw under the footer without receiving its touches.
private struct MapPanArea: Shape {
    let bottomInset: CGFloat
    func path(in rect: CGRect) -> Path {
        Path(CGRect(x: rect.minX, y: rect.minY, width: rect.width,
                    height: max(0, rect.height - bottomInset)))
    }
}
