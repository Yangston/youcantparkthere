# Architecture and honest platform boundaries

## Components

`GBFSClient (actor) → StationSnapshot → AppModel (@MainActor) → SwiftUI map/list/detail`.

The watch fetches public HTTPS JSON directly from the operator. Discovery supplies station-information and station-status URLs. Only HTTPS feeds on the configured operator hostname are accepted. Information is cached for six hours; status requests obey `max(30 seconds, feed TTL)`. An in-flight task coalesces overlapping requests. The UI's loop checks every five seconds but does **not** request the feed every five seconds. Failed fetches back off up to five minutes.

The decoder accepts GBFS 1/2 numeric timestamps and GBFS 3 ISO-8601 timestamps, localized names, numeric/string IDs, numeric/boolean flags, and `num_vehicles_available` versus legacy `num_bikes_available`. Invalid coordinates are dropped, duplicate IDs do not crash, missing status flags fail closed, and missing counts remain unknown. Only public station inventory is cached to disk; user location and motion samples are not persisted.

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

Map distances are geodesic straight-line distances, not road routing or ETAs. Apple Maps handoff shows the selected station; this version does not compute turn-by-turn directions. A target-full warning only follows a fresh available → full transition, never a request failure. Location and feed error handling must remain separate from inventory claims.

## Privacy and release limits

No backend, analytics, account, route history, or motion log exists. Apple Maps still requests map tiles and may process location-related information under Apple's policies, and the operator's HTTPS service sees network requests/IP addresses. A privacy manifest declares the app's own UserDefaults use. Public-release privacy disclosures must be reviewed against the final binary and any future SDKs.

The bundle contains a watch application, a watch WidgetKit extension, and a non-launchable watch-only iOS distribution container. The XcodeGen project is generated rather than hand-edited. CI checks archive structure, not Apple acceptance. TestFlight signing and physical-device testing are separate release gates.

Future work should prioritize real-watch motion/wrist-raise validation, then route-aware station selection, bike-type filtering, optional destination search, and smarter low-dock warnings. Do not expand into cloud services or collect trip history unless a feature demonstrably needs them.

Primary references: [Core Motion](https://developer.apple.com/documentation/coremotion/cmmotionactivitymanager), [Background sessions](https://developer.apple.com/documentation/watchkit/enabling-background-sessions), [GBFS](https://gbfs.org/documentation/).
