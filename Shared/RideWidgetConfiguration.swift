import AppIntents

/// Shared by the app's relevance donation and the matching widget configuration.
struct RideWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Cycling shortcut"
    static var description = IntentDescription("Quick access to the dock map when cycling is detected.")
    static let kind = "ActiveRideShortcut"
}
