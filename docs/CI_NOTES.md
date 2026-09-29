# CI failures and verification boundaries

## The original three red runs

Reviewed from each run's saved `watch-build` artifact, specifically `simulator-smoke.log`. These were real failed automation runs, even though compilation had succeeded. They should not have been presented as fully validated builds.

| Run | Failure recorded in the artifact | What it establishes |
|---|---|---|
| [Run 2](https://github.com/Yangston/youcantparkthere/actions/runs/36608236758) | `simctl openurl ... youcantparkthere://bikes` failed with OSStatus `-10814`. | The app installed, launched, stayed alive, and produced a screenshot before generic URL dispatch failed. This run did not fail because the app lacked a paired simulator. |
| [Run 3](https://github.com/Yangston/youcantparkthere/actions/runs/36609374310) | `pair_activate` returned code `37`: `This pair is already active.` | The harness treated an already-active simulator pair as fatal. Cleanup also emitted warnings for already-shutdown devices. |
| [Run 4](https://github.com/Yangston/youcantparkthere/actions/runs/36610231334) | After the pair-activation fix, `simctl openurl` again failed with OSStatus `-10814`. | Pairing did not fix the generic URL-dispatch test. The app did launch and produce a screenshot. |

The archived watch app's Info.plist includes its `youcantparkthere` URL scheme. That alone is not proof that an arbitrary `simctl openurl` command can deliver that URL on watchOS, nor proof that real widget delivery works.

## What changed

Commit `a40a8bd0195888f76c525cd50713d7dc3b228358` keeps the disposable paired simulators and narrowly accepts only the known already-active result. It replaces generic URL dispatch with explicit **in-app routing assertions**, through the production route handler:

- A Debug + simulator-only launch hook accepts `--demo --smoke-url <URL>` and invokes the same `AppModel.open` method used by `.onOpenURL`.
- The app writes its actual mode, ride state, tab, demo status, and accepted URL to its simulator cache. The harness requires that exact expected state for docks, bikes, and ride.
- A previous report is removed before every fresh launch. Missing reports, wrong state, invalid process IDs, and app crashes still fail the job. A screenshot alone is not considered success.
- Reports and screenshots are retained as artifacts. Cleanup warnings cannot replace an earlier test failure.
- Four Swift route tests and six Python harness tests were added. Unknown URLs are now rejected instead of silently switching to parking.
- The run summary lists each check separately, including the optional live-feed diagnostic.

The app's widgets still use `widgetURL`, and the app still receives URLs through `.onOpenURL`. Apple documents that containing-app path in [widgetURL](https://developer.apple.com/documentation/SwiftUI/View/widgetURL(_:)) and [widget interaction handling](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension). The new test does not claim to emulate the OS portion of that interaction.

## What a passing run does NOT mean

This is deliberately a boundary, not a hidden pass condition: **real complication taps and Siri activation are not end-to-end verified by this simulator harness**. They remain mandatory items in [DEVICE_TESTS.md](DEVICE_TESTS.md). The Debug simulator reporting hook is not compiled into the physical-device/release path.

Likewise, an unsigned archive does not prove signing or TestFlight acceptance. A demo launch does not test GPS, real motion classification, battery, network handoffs, background execution, or wrist-raise presentation on Stone's watch.

## How to inspect the current result

Open [Build and test](https://github.com/Yangston/youcantparkthere/actions/workflows/build.yml), choose the latest relevant code commit, and read **What this run checked**. The original red runs remain part of history. A docs-only commit may explicitly skip CI; that does not skip tests for a code change. A queued/running job is not a success.

For details, download a completed run's `watch-build` artifact. Prefer its small `simulator-smoke.log`, `helper-tests.log`, and `tests.log` over the entire Xcode job log. `demo-*.json` contains sample route state, not credentials or GPS history. Use [SETUP.md](SETUP.md) for the separate signing/installation path.
