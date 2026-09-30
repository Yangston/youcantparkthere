# Architecture and honest platform boundaries

## Components

`GBFSClient (actor) → StationSnapshot → AppModel (@MainActor) → SwiftUI map/detail/settings`.

Production screens live in `WatchApp/Views/`. `preview/fixtures.json` supplies the local interaction sketch and the Debug simulator preview harness. `SimulatorPreview` configures only in-memory sample state and disables live services in that mode; its fixture loading and presentation logic is compiled out of device/Release builds. The HTML sketch is a separate approximation, while native screenshot reports use the production SwiftUI views. See [DEVELOPMENT.md](DEVELOPMENT.md) for the capture/assertion boundary.

The watch fetches public HTTPS JSON directly from the operator. Discovery supplies station-information and station-status URLs. Only HTTPS feeds on the configured operator hostname are accepted. Information is cached for six hours; status requests obey `max(30 seconds, feed TTL)`. An in-flight task coalesces overlapping requests. The UI's loop checks every five seconds but does **not** request the feed every five seconds. Automatic retries after failed fetches back off up to five minutes. An explicit Retry/Refresh bypasses that failure backoff while the client still coalesces requests and respects successful-response TTL. The no-data Retry control replaces the map header so it cannot overlap other buttons.

The decoder accepts GBFS 1/2 numeric timestamps and GBFS 3 ISO-8601 timestamps, localized names, numeric/string IDs, numeric/boolean flags, and `num_vehicles_available` versus legacy `num_bikes_available`. Invalid coordinates are dropped, duplicate IDs do not crash, missing status flags fail closed, and missing counts remain unknown. Only public station inventory is cached to disk; user location and motion samples are not persisted.

E-bike counts join `vehicle_types_available` to the optional `vehicle_types` feed, selecting bicycles with `electric_assist` or `electric` propulsion and excluding electric scooters. Missing/malformed/unknown classifications remain unknown. Omitted zero-count types are inferred only when the breakdown accounts for the total inventory, or all electric types have explicit counts. Optional type-feed failures preserve docks and total bikes and retry metadata after five minutes. Type metadata is otherwise cached for six hours. Old station caches decode with unknown e-bike counts. E-bike inventory uses the same freshness and renting/installed gates as total bikes.

The root lays out a full-width map canvas above a dedicated 56-point bottom strip. The strip contains update age on the left, a 44-point recenter target in the center, Park/Bikes on the right, and the two page dots. MapKit's view bounds end above this strip; a horizontal high-priority drag on the strip changes pages with one finger, including when starting over a button or dot. This replaces the nested native TabView/map recognizers that required two fingers on the physical Watch. Settings supports a right swipe back. Only native device testing can confirm gesture reliability.

Visible markers stay compact with 44-point hit regions. Pressed feedback and haptics acknowledge actions. `MapSheet` presents station details only. No Start/End Ride controls or start-ride Siri shortcut remain. The legacy `youcantparkthere://ride` URL opens the dock map without starting tracking.

`MapViewport` selects from the full cached feed within the camera bounds plus a 10% edge buffer, sorts by geodesic distance to the camera center (station ID breaks ties), and renders at most 30. Panning never ranks from GPS or sends a new feed request. Offscreen stations stay cached for returning. Continuous camera callbacks are throttled to 120 ms, with a final update after a gesture. The default recenter span is 0.009 latitude by 0.012 longitude, 25% tighter per dimension. Freshness and closed/unknown inventory remain independent of spatial selection.

Bikes shows total bikes, with lightning for fresh positive e-bike availability and the breakdown in station details.

Opening the map or returning to an active, undimmed scene restores location following and recenters on the latest known position. Both `scenePhase` activation and the end of reduced luminance are observed to cover ordinary wake and Always On transitions. A fresh GPS fix arriving after wake moves the camera again. Manual panning pauses following only until the next activation or recenter-button tap. Location permission and the active-Ride-only background-location rule remain in effect. Location quality is shown in Settings and announced by the recenter control.

A status count is usable only when the publication and fetch are at most two minutes old, the station report is at most five minutes old, and the station is installed and accepting the relevant operation. A timestamp more than a minute into the future is invalid for freshness. These are conservative product thresholds, not guarantees made by the feed operator. Fresh zero, station unavailable, and unknown/stale are distinct states.

## Automatic cycling

Motion detection is opt-in through **Automatic cycling** in Settings; existing preferences are preserved. There is no per-trip Start or End action. Core Motion must provide confident, unambiguous cycling evidence for 12 seconds while the app is active before navigation starts. The app switches to Park and requests a dated Smart Stack suggestion. With location permission, navigation can continue receiving background location while that detected cycling state is active.

The same detector automatically stops after 60 seconds of confident walking/driving/running, or 180 seconds of stationary evidence to tolerate short traffic lights. Conflicting/unknown or low-confidence activity does not pretend to prove either cycling or stopping. Stopping is evaluated only while the app can execute. Background navigation has a 90-minute ceiling. Turning automatic detection off or reaching that ceiling stops navigation and suppresses restart for five minutes. A normal sensor-detected stop can qualify again on new cycling evidence. Opt-out remains immediate even though the old End button is gone.

Core Motion cannot wake a closed app merely because cycling starts. watchOS may suspend delivery; this is not Fitness's privileged always-on workout detection. No fake workout, silent audio, extended-runtime workaround or HealthKit recording is used. See [motion update delivery](https://developer.apple.com/documentation/coremotion/cmmotionactivitymanager/startactivityupdates(to:withhandler:)).

The app donates a `RelevantIntent` for the cycling shortcut, dated from detection to its 90-minute ceiling. It clears relevance on detected stop, timeout, opt-out, disabling suggestions, and reopening without an active detected session. Updates are serialized. The widget kind `ActiveRideShortcut` and preference key `suggestRide` remain stable for installed users, but the visible name is Cycling shortcut. The widget remains a launcher without live inventory or a claim that it knows current activity. watchOS chooses ordering, suggestions and any clock-screen hint; the app cannot force itself to the top. Simulator fixtures never donate actual relevance. See [Apple's Smart Stack guidance](https://developer.apple.com/documentation/widgetkit/widget-suggestions-in-smart-stacks).

Map distances are geodesic straight-line distances, not road routing or ETAs. Apple Maps handoff shows the selected station; this version does not compute turn-by-turn directions. A target-full warning only follows a fresh available → full transition, never a request failure. Location and feed error handling must remain separate from inventory claims.

## Privacy and release limits

No backend, analytics, account, route history, or motion log exists. Apple Maps still requests map tiles and may process location-related information under Apple's policies, and the operator's HTTPS service sees network requests/IP addresses. A privacy manifest declares the app's own UserDefaults use. Public-release privacy disclosures must be reviewed against the final binary and any future SDKs.

The bundle contains a watch application, a watch WidgetKit extension, and a non-launchable watch-only iOS distribution container. The XcodeGen project is generated rather than hand-edited. CI checks archive structure, not Apple acceptance. TestFlight signing and physical-device testing are separate release gates.

Future work should prioritize real-watch motion/wrist-raise and Smart Stack validation, then route-aware station selection, optional destination search, and smarter low-dock warnings. Do not expand into cloud services or collect trip history unless a feature demonstrably needs them.

Primary references: [Core Motion](https://developer.apple.com/documentation/coremotion/cmmotionactivitymanager), [Background sessions](https://developer.apple.com/documentation/watchkit/enabling-background-sessions), [GBFS](https://gbfs.org/documentation/).
