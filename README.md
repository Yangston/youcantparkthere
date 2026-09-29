# You Can't Park There

[![Build and test](https://github.com/Yangston/youcantparkthere/actions/workflows/build.yml/badge.svg)](https://github.com/Yangston/youcantparkthere/actions/workflows/build.yml)

A watch-first Bike Share Toronto app: find an empty dock without pulling out your phone.

**v0.1 implementation.** SwiftUI watch app, WidgetKit complications, native location/motion integration, public GBFS client, tests, and cloud builds. Physical-watch behavior and signed TestFlight distribution still need device/account validation. The CI badge is the current build status, not a claim of road testing.

## The experience

Open **Find a Dock** from your watch face → tap **Ride** → raise your wrist to see nearby stations and empty-dock counts. Swipe for the distance-sorted list or settings. Toggle **Park / Bikes** to choose what you need.

| Feature | Implementation |
|---|---|
| Wrist map | Nearby station count markers; green = 3+, yellow = 1–2, red = 0, gray/dash = unknown or unavailable. |
| Live availability | Fetches the operator's GBFS feed directly; no API key or Bike Share login. |
| Nearby list | Straight-line distance, 5 km radius, minimum-dock filter, favorites. Not a calculated cycling route. |
| Destination | Pick a station; haptic when within 60 m; warning when a freshly observed target goes from available to full. |
| Ride mode | Explicit start/end, background location navigation, 90-minute safety cutoff. No HealthKit workout. |
| Cycling detection | Opt-in sustained Core Motion cycling evidence **while the app is open**. Never claims to wake a closed app. |
| Quick launch | Find Docks / Find Bikes complications and Siri/App Intents. Widgets are launchers, not cached counts presented as live. |
| Offline behavior | Last station snapshot preserved, timestamps shown, stale inventory never advertised as fresh availability. |
| Privacy | No account, analytics, backend, recorded route, or uploaded motion samples. Maps/operator network traffic still occurs. |

## What this cannot promise

- A third-party watch app cannot silently bring itself to the foreground whenever you start cycling. Open it once or explicitly start a ride. Core Motion availability and accuracy vary by device.
- Background location sessions support wrist-raise return, but watchOS settings, other apps, battery modes, interruptions, and network availability still matter. **Always visible** does not mean an always-lit or always-refreshed display.
- No bike unlocking, dock reservation, payment integration, return confirmation, turn-by-turn routing, or predicted future availability. Available-bike counts combine bike types in this version.
- A proximity haptic is **not** confirmation that a bike is returned. Confirm the station's successful docking signal. Stop safely before interacting with the map.

## Install from Windows

Read **[docs/SETUP.md](docs/SETUP.md)**. Code editing happens on Windows; GitHub's macOS runner compiles and signs; TestFlight handles installation through your paired iPhone. You do not need a local Mac.

1. **Build and test** runs automatically on pushes to `main` and pull requests, without Apple credentials.
2. Configure your Apple Developer / App Store Connect identifiers and GitHub environment secrets.
3. Manually run **Upload to TestFlight**. It is deliberately not run on every push or pull request and does not submit a public App Store release.

A simulator `.app` from CI **cannot** be installed on a real watch. A successful unsigned archive does not prove that Apple signing/upload succeeds.

## Development

Requirements for native builds: Xcode with watchOS SDK, XcodeGen 2.42+, Python 3. Core-only tests also run with Swift 5.9+ on Linux/macOS.

```sh
swift test                         # deterministic, no network
swift run ParkFeedCheck             # optional live operator check
python3 scripts/make_assets.py
xcodegen generate
xcodebuild -project YouCantParkThere.xcodeproj -scheme ParkWatch \
  -sdk watchsimulator -destination 'generic/platform=watchOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

Launch the watch app with `--demo` for clearly labeled sample stations. Demo data is never a fallback for a failed live request.

## Repository

```text
Sources/ParkCore/       GBFS decoder/client, distance/filtering, ride and alert state machines
Tests/ParkCoreTests/    Malformed/stale/closed/full feeds, geometry, cache/TTL, motion, alerts
Sources/ParkFeedCheck/  Live feed diagnostic
WatchApp/              SwiftUI map/list/detail/settings, GPS, ride session, intents, privacy manifest
Widgets/               Watch-face and Smart Stack launchers
project.yml            Reproducible XcodeGen project; watch + widgets + watch-only iOS packaging
.github/workflows/     Unsigned CI and manual signed TestFlight upload
scripts/               Asset generation, signing preflight, archive structure checks
docs/                  Setup, architecture/platform constraints, physical-device test checklist
```

## Data and platform references

Data is supplied by **Bike Share Toronto / Toronto Parking Authority**. This is an unofficial project, not affiliated with or endorsed by the operator. Feed attribution/license details should be rechecked before public distribution.

- [Operator GBFS discovery](https://toronto.publicbikesystem.net/customer/gbfs/v3.0/gbfs.json)
- [MobilityData catalog entry](https://mobilitydatabase.org/feeds/gbfs/gbfs-bike_share_toronto)
- [GBFS specification](https://gbfs.org/documentation/)
- [Apple background navigation sessions](https://developer.apple.com/documentation/watchkit/enabling-background-sessions)
- [Apple Core Motion activity manager](https://developer.apple.com/documentation/coremotion/cmmotionactivitymanager)
- [Apple display and Return to Clock settings](https://support.apple.com/guide/watch/adjust-the-display-settings-apd127ec93ac/watchos)
- [Codemagic CLI signing](https://docs.codemagic.io/yaml-code-signing/alternative-code-signing-methods/)
