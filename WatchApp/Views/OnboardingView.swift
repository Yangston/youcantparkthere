import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    let onContinue: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "parkingsign.circle.fill").font(.largeTitle).foregroundStyle(.orange)
                Text("You Can't\nPark There").font(.title2.bold())
                Text("Find a bike. Find an empty dock. Leave your phone in your pocket.")
                Text("Start Ride keeps navigation active. Auto-detection works only while this app is running—not from a closed app.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Enable location") { onContinue(); model.requestLocation() }.buttonStyle(.borderedProminent)
                Button("Browse downtown") { onContinue() }
                Text("Not affiliated with Bike Share Toronto. Availability can change. Stop safely before interacting.")
                    .font(.caption2).foregroundStyle(.secondary)
            }.padding()
        }
    }
}
