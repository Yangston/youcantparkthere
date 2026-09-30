# Continual development

Edit on Windows. Use the local studio for fast interaction exploration and GitHub's macOS runners for **actual SwiftUI compilation and screenshots**. A local Mac is optional.

## Local tools and loop

Install Python 3.10+ and Node.js 20+ (tests use Node's built-in test runner). There are no Python or npm dependencies to install. GitHub CLI is optional for requesting/downloading CI previews; the browser Actions UI does the same work.

```powershell
git switch -c feature/my-change
python scripts/dev.py check
python scripts/dev.py preview
```

Open `http://127.0.0.1:8765`. Stop with Ctrl+C. The server binds to loopback and serves only preview assets/screenshots, never the repository or private key files. Refresh after editing the studio's CSS/JS or fixtures. The downloaded studio also works offline by opening `index.html`.

`check` runs the Python tooling tests and JavaScript sketch-logic tests. If Swift is installed it also runs `swift test`; otherwise it explicitly reports that Swift was **not run locally**. Native CI remains required. You do not need Xcode, Swift or Apple credentials on Windows to use the hosted native workflow.

## The two preview surfaces

| Surface | Use it for | Evidence boundary |
|---|---|---|
| Interaction sandbox | Click through modes, station selection, destination, favorites, Ride/End, e-bike filtering, onboarding and error states | HTML approximation. No SwiftUI compilation, real sensor, GPS, maps handoff or background execution. Editing SwiftUI does not automatically change this sketch. |
| Native captures | Review the actual map/detail/settings/onboarding layouts, compact/large Watch displays, accessibility text, stale/offline/closed/empty/error states | The current SwiftUI app compiled and launched in watchOS Simulator. Scenario state and process survival are asserted. Screenshots still need human visual review. |
| Physical Watch | Permission prompts, complications/Siri, background behavior, GPS/motion, haptics, battery and connectivity | Record only tests actually performed in DEVICE_TESTS.md. |

The shared scenario catalog is `preview/fixtures.json`. Sample data is intentional and labeled. It is never a fallback for a failed live request. The native fixture code activates only in **Debug simulator** builds; `--demo` and `--preview-scenario` cannot activate it on a physical-device or Release build.

## Get native previews before a Watch update

Push your feature branch and open a PR. **Build and test** runs automatically on PRs and pushes to `main`. For a pushed branch without a PR, use Actions > Build and test > Run workflow and select that branch.

Optional GitHub CLI shortcuts, after `gh auth login`:

```powershell
python scripts/dev.py capture --ref feature/my-change
python scripts/dev.py fetch --run RUN_ID --profile compact
python scripts/dev.py preview
```

`capture` does not commit or push local files. Only the commit already on GitHub is built. `fetch` downloads `watch-preview-compact` (or `--profile large`) and imports it into the local studio. It requires a completed run with that artifact.

Without GitHub CLI:

1. Open the completed run's Summary. Review every check and both native jobs.
2. Download `watch-preview-compact` and `watch-preview-large` from Artifacts or the preview links in the summary.
3. Extract either ZIP and open `index.html`; select **Native captures**. Or import it into the running local studio:

```powershell
python scripts/dev.py import C:\path\to\watch-preview-compact.zip
```

4. Refresh the local studio. Check the displayed **commit, branch, Watch model, runtime and capture time**. A capture from an older commit does not verify your current edit.
5. Select each changed screen/state. Native images are static viewport captures; scrollable pages show the captured viewport, not an interactive simulator. Missing screenshots and failed state assertions are explicitly shown as missing/failed, never as a passed preview.
6. To save a repeatable comparison without a browser folder picker:

```powershell
python scripts/dev.py baseline C:\path\to\older-watch-preview-compact.zip
```

Refresh and select **Use saved baseline**. Alternatively, select **Load baseline folder** and choose an extracted older report folder. Use side-by-side or wipe overlay. Baselines must use the same Watch model/runtime. Map tiles, OS clock and rendering can vary; this is a visual review, not an automated pixel-diff pass.

Artifacts expire after 30 days. Keep an extracted known-good preview outside the repository for longer-lived baselines. The simulator `.app` cannot be installed on a physical Watch.

## Testing pipeline

- **Windows tooling job:** Python helper/import/report/release-gate tests and JS freshness/filter semantics.
- **Two native jobs:** compact and large Watch devices selected from the newest available runtime. Actual model/runtime names are recorded rather than guessed.
- **Each native job:** helper tests > `swift test` > assets/XcodeGen > Watch + widgets compilation > unsigned archive validation > optional live feed diagnostic > paired-simulator route assertions > 14 scenario state assertions/screenshots > offline preview report.
- **Partial failures:** available screenshots and logs are still uploaded, with failed/missing states visible. CI remains red when any required step fails.
- **Live feed:** remote outages are diagnostic and do not masquerade as deterministic test failures.
- **Signed distribution:** a separate manual workflow restricted to `main` and the protected `testflight` environment. It requires green unsigned CI for the exact commit. See RELEASING.md.

Native previews exercise the same production views and route handler. They do not simulate watchOS delivering a complication URL. Do not replace this boundary with `simctl openurl`: generic URL dispatch has failed on watchOS even when the app launched correctly.

A fresh paired simulator may spend minutes migrating system data. The harness allows one retry of a read-only `simctl list devices` timeout; application crashes and incorrect state reports are never retried into a pass. For an infrastructure failure, inspect `simulator-smoke.log`, then rerun the unchanged failed job. Keep the original failure visible.

Between captures, the harness explicitly terminates the app, verifies process exit, and lets the old scene disconnect before the next launch. This avoids combining termination and relaunch in one `simctl` command, which can produce a watchOS "Scene update failed" refusal. Launch failures still fail CI; app/Carousel diagnostic logs are collected when available.

## Adding or changing a feature

1. Change the production screen in `WatchApp/Views/`, or behavior in `AppModel` / `ParkCore`.
2. Add meaningful deterministic core tests for changed logic. Do not alter freshness, motion opt-in or ride-stop semantics just to satisfy a preview.
3. Add/adjust a scenario in `preview/fixtures.json`. `SimulatorPreview` loads it; the harness independently checks expected mode, tab, ride state and usable counts. Extend both schema readers when adding a new fixture field.
4. If the interaction flow changes, update the approximate sandbox separately in `preview/app.js`. The shared fixtures prevent data drift; they do not make HTML a SwiftUI renderer.
5. Review both native device reports and large-text captures, then merge. Record relevant hardware checks when you choose to install a new beta.

The fixture `overrides` supports `returning` and explicitly null `docks` or `electricBikes` values. `bikeFilter` selects `all` or `electric` while `mode` remains `bikes`. The removed nearby page is not a valid preview screen. Station report/publication ages are equal in these scenarios; finer freshness edge cases live in the Swift unit tests.

## Optional local native work on a Mac

```sh
swift test
python3 scripts/make_assets.py
xcodegen generate
xcodebuild -project YouCantParkThere.xcodeproj -scheme ParkWatch \
  -configuration Debug -sdk watchsimulator -destination 'generic/platform=watchOS Simulator' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
python3 scripts/simulator_smoke.py --profile compact
python3 scripts/preview_report.py
```

Keep generated projects, assets, build output and signing material ignored. `project.yml` defines bundle metadata and capabilities. Never hand-edit a generated Info.plist as the durable fix.
