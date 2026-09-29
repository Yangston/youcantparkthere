# You Can't Park There

[![Build and test](https://github.com/Yangston/youcantparkthere/actions/workflows/build.yml/badge.svg)](https://github.com/Yangston/youcantparkthere/actions/workflows/build.yml)

A native Apple Watch app for finding Bike Share Toronto bikes and empty docks. SwiftUI, public GBFS data, no account or backend. Stone confirmed installation and launch on a physical Watch on 29 September 2026; detailed device acceptance is tracked separately.

## Daily development from Windows

```powershell
python scripts/dev.py check
python scripts/dev.py preview
```

Open **http://127.0.0.1:8765**. The preview studio has an interactive behavior sketch and a gallery of **actual native simulator screenshots**. The sketch is explicitly approximate; it does not compile SwiftUI. Both use the same sample scenarios.

1. Make a branch and edit the native app.
2. Run local checks and explore the interaction sandbox.
3. Push the branch and open a PR, or manually run **Build and test** for that branch.
4. Download **watch-preview-compact** and **watch-preview-large** from the run. Extract and open `index.html` to review all 13 states and compare an older capture folder.
5. Merge to `main`, wait for CI, and manually run **Upload to TestFlight** only when you want a Watch update.

No Apple keys are required for previews. No push or PR automatically uploads to TestFlight.

## Guides

- [Development and preview workflow](docs/DEVELOPMENT.md): local commands, screenshot review, test coverage, adding scenarios.
- [Release checklist](docs/RELEASING.md): exact-commit CI gate, TestFlight processing, installation and rollback.
- [Apple signing reference](docs/APPLE_SIGNING.md): the two different private keys, identifiers, portal nuances and recovery.
- [Architecture](docs/ARCHITECTURE.md): data freshness, motion and background lifecycle constraints.
- [Device testing](docs/DEVICE_TESTS.md): actual evidence and remaining hardware checks.

## App behavior

- **Park / Bikes:** map markers and a list ordered by straight-line distance.
- **Availability:** green = 3+, yellow = 1?2, red = fresh zero, gray = unknown or unavailable. Stale counts are never shown as fresh inventory.
- **Ride:** explicit start/end, background navigation location, 90-minute cutoff and five-minute automatic-restart suppression after ending.
- **Cycling detection:** opt-in, only while the app is executing. It cannot launch a closed app.
- **Destinations:** proximity and newly-full warnings; neither reserves a dock nor confirms a successful return.
- **Complications:** intentional launchers, not live inventory widgets.
- **Privacy:** no analytics, route history or uploaded GPS/motion samples. Apple Maps and the public feed still make network requests.

## Source map

| Path | Responsibility |
|---|---|
| `WatchApp/Views/` | Native SwiftUI screens and formatting |
| `WatchApp/AppModel.swift` | Live data, permissions, ride session and services |
| `WatchApp/PreviewSupport.swift` | Simulator-only fixtures and screenshot presentation |
| `Sources/ParkCore/` | Portable data parsing, freshness, ranking, ride and route logic |
| `Widgets/` | Watch-face and Smart Stack launchers |
| `preview/` | Local studio, shared fixtures and sketch logic tests |
| `scripts/` | Repeatable checks, previews, asset generation and archive validation |
| `project.yml` | XcodeGen source of truth; generated projects stay ignored |
| `.github/workflows/` | Unsigned validation/preview and separate manual signed distribution |

Data: Bike Share Toronto / Toronto Parking Authority. Unofficial app; not affiliated with the operator. Recheck attribution and licensing before a public release. [GBFS discovery](https://toronto.publicbikesystem.net/customer/gbfs/v3.0/gbfs.json) ? [GBFS specification](https://gbfs.org/documentation/).
