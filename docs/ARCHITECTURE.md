# Architecture and honest platform boundaries

## Components

`GBFSClient (actor) → StationSnapshot → AppModel (@MainActor) → SwiftUI map/detail/settings`.

Production screens live in `WatchApp/Views/`. `preview/fixtures.json` supplies the local interaction sketch and the Debug simulator preview harness. `SimulatorPreview` configures only in-memory sample state and disables live services in that mode; its fixture loading and presentation logic is compiled out of device/Release builds. The HTML sketch is a separate approximation, while native screenshot reports use the production SwiftUI views. See [DEVELOPMENT.md](DEVELOPMENT.md) for the capture/assertion boundary.

The watch fetches public HTTPS JSON directly from the operator. Discovery supplies station-information and station-status URLs. Only HTTPS feeds on the configured operator hostname are accepted. Information is cached for six hours; status requests obey `max(30 seconds, feed TTL)`. An in-flight task coalesces overlapping requests. The UI's loop checks every five seconds but does **not** request the feed every five seconds. Failed fetches back off up to five minutes.

The decoder accepts GBFS 1/2 numeric timestamps and GBFS 3 ISO-8601 timestamps, localized names, numeric/string IDs, numeric/boolean flags, and `num_vehicles_available` versus legacy `num_bikes_available`. Invalid coordinates are dropped, duplicate IDs do not crash, missing status flags fail closed, and missing counts remain unknown. Only public station inventory is cached to disk; user location and motion samples are not persisted.

E-bike counts join `vehicle_types_available` to the optional `vehicle_types` feed, selecting bicycles with `electric_assist` or `electric` propulsion and excluding electric scooters. Missing/malformed/unknown classifications remain unknown. Omitted zero-count types are inferred only when the breakdown accounts for the total inventory, or all electric types have explicit counts. Optional type-feed failures preserve docks and total bikes and retry metadata after five minutes. Type metadata is otherwise cached for six hours. Old station caches decode with unknown e-bike counts. E-bike inventory uses the same freshness and renting/installed gates as total bikes.

The map and its overlay layout fill the display. Park/Bikes sits at the upper-left edge, utilities at the far-right edge, and Ride/End at the lower-right edge. Small insets preserve rounded corners, the system clock, and MapKit attribution. Bikes always shows the total bike count, with a lightning indicator for fresh positive e-bike availability and a separate detail count. The visible count capsule is at least 20 points with tighter number padding and an expanded invisible tap region. `MapSheet` routes settings and station details; there is no nearby-list tab or list-only minimum-docks preference.

Opening the map or returning to an active, undimmed scene restores location following and recenters on the latest known position. Both `scenePhase` activation and the end of reduced luminance are observed to cover ordinary wake and Always On transitions. A fresh GPS fix arriving after wake moves the camera again. Manual panning pauses following only until the next activation or recenter-button tap. Location permission, stale/no-GPS labels, and the active-Ride-only background-location rule remain in effect.

A status count is usable only when the publication and fetch are at most two minutes old, the station report is at most five minutes old, and the station is installed and accepting the relevant operation. A timestamp more than a minute into the future is invalid for freshness. These are conservative product thresholds, not guarantees made by the feed operator. Fresh zero, station unavailable, and unknown/stale are distinct states.

## Ride state machine

| State | Behavior |
|---|---|
| Browsing | Location while the app is active; normal feed updates; no background location after leaving. |
| Detecting (opt-in) | While active, Core Motion observes cycling. Twelve seconds of confident, unambiguous cycling can start a ride. Evidence older than 45 seconds is rejected. |
| Riding | Show parking mode, request background location, update center as position changes, refresh public station data subject to OS scheduling. |
| Ended | Stop background location, clear alert state, suppress auto-restart for five minutes. |
| Timeout | Stop after 90 minutes to avoid accidentally running GPS indefinitely. |

The classifier rejects low confidence and conflicting driving/walking/running/stationary signals. It does not infer cycling from GPS speed alone, which would misclassify cars and transit. Red lights do not automatically end a ride. Physical-watch calibration remains necessary.

## Background behavior

Apple's supported location background mode is used for the actual navigation session. It starts through an explicit Ride action or previously enabled foreground cycling detection. No empty workout, silent audio, mindfulness session, background polling service, or private API is used to keep the process alive.

The OS owns suspension, refresh timing, network transport, and presentation. The app cannot wake itself and seize the display just because motion data later says cycling. The most dependable v0.1 flow is one-tap launch and explicit Ride. Complications are launchers rather than misleading 'live' counts, because WidgetKit controls update budgets.

While Ride is active, the app donates a `RelevantIntent` for the `ActiveRideShortcut` widget, scoped from the actual ride start to its 90-minute limit. Donations are serialized so End cannot be overwritten by a delayed start. End, timeout, disabling the shortcut, or reopening without a ride clears the donation. The widget is a dock-map launcher with no inventory or unverified active-state claim. It needs no HealthKit, fake workout, app group, new backend, or continuous background motion polling. Smart Stack suggestions and any clock-screen hint are chosen by watchOS and user settings; donation is not proof of presentation. Simulator fixtures do not donate real relevance. See [Apple's Smart Stack relevance guidance](https://developer.apple.com/documentation/widgetkit/widget-suggestions-in-smart-stacks).

Map distances are geodesic straight-line distances, not road routing or ETAs. Apple Maps handoff shows the selected station; this version does not compute turn-by-turn directions. A target-full warning only follows a fresh available → full transition, never a request failure. Location and feed error handling must remain separate from inventory claims.

## Privacy and release limits

No backend, analytics, account, route history, or motion log exists. Apple Maps still requests map tiles and may process location-related information under Apple's policies, and the operator's HTTPS service sees network requests/IP addresses. A privacy manifest declares the app's own UserDefaults use. Public-release privacy disclosures must be reviewed against the final binary and any future SDKs.

The bundle contains a watch application, a watch WidgetKit extension, and a non-launchable watch-only iOS distribution container. The XcodeGen project is generated rather than hand-edited. CI checks archive structure, not Apple acceptance. TestFlight signing and physical-device testing are separate release gates.

Future work should prioritize real-watch motion/wrist-raise and Smart Stack validation, then route-aware station selection, optional destination search, and smarter low-dock warnings. Do not expand into cloud services or collect trip history unless a feature demonstrably needs them.

Primary references: [Core Motion](https://developer.apple.com/documentation/coremotion/cmmotionactivitymanager), [Background sessions](https://developer.apple.com/documentation/watchkit/enabling-background-sessions), [GBFS](https://gbfs.org/documentation/).
