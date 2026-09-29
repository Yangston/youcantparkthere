import AppIntents

/// Shared by the app's relevance donation and the matching widget configuration.
struct RideWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Ride shortcut"
    static var description = IntentDescription("Quick access to the dock map during a Ride.")
    static let kind = "ActiveRideShortcut"
}
