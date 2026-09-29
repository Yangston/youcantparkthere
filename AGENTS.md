# Working on You Can't Park There

This is a native watchOS application, not a web prototype. Stone edits on Windows; native builds run in GitHub Actions macOS. Do not make owning a Mac a prerequisite for the documented workflow.

- Run `swift test` for the portable core. Generate assets with `python3 scripts/make_assets.py`, then `xcodegen generate` for native builds.
- `project.yml` is the source of truth. Never commit generated Xcode projects or signing files.
- Distinguish fresh zero inventory from unknown, stale, missing, or closed-station data. Never turn a network error into a full station or show demo stations as a live fallback.
- No server/API key is required for GBFS. Never upload user GPS/motion data merely to rank nearby stations.
- Keep motion detection opt-in and its app-lifecycle constraints explicit. No fake workouts, silent audio, or inappropriate extended-runtime categories.
- Background location belongs only to an active navigation ride. Preserve manual stop, time limit, and auto-restart suppression.
- Widgets are intentional launchers. Do not add 'live' counts without freshness and refresh-budget design.
- The active-Ride Smart Stack suggestion is system-controlled, not passive closed-app cycling detection. Clear its dated relevance on End/timeout/opt-out and never promise a forced clock banner.
- E-bike counts come from GBFS vehicle-type metadata and obey normal freshness/operational checks. Missing type data is unknown, not zero; electric scooters are not e-bikes.
- Signed TestFlight upload is manual and `main`-only. Credentials go exclusively in GitHub's protected `testflight` environment; never in source, issues, logs, or chat.
- Update `docs/DEVICE_TESTS.md` only with tests actually run. Successful simulator compilation is not physical-device validation.
- Daily workflow: `python scripts/dev.py check`, then `python scripts/dev.py preview`. Follow `docs/DEVELOPMENT.md`; use `docs/APPLE_SIGNING.md` and `docs/RELEASING.md` for distribution.
- The local HTML sandbox is an approximation. Native captures are the SwiftUI visual evidence; keep their commit/device/runtime provenance visible and never label missing captures as passed.
- Share deterministic preview cases through `preview/fixtures.json`. Preview hooks must stay Debug + simulator-only; never activate sample data or suppress real permissions in release/device builds.
- Before signed upload, require successful unsigned CI for the exact main commit. Preview workflows must never receive Apple signing secrets or dispatch TestFlight automatically.
