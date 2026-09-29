# Release a new Watch beta

Development previews and Watch updates are separate. Use this checklist only when a change is ready to install. A push or PR never starts signed distribution automatically.

## Before upload

- Merge the reviewed change to `main`.
- Wait for **Build and test** to pass on that exact commit, including both native sizes. Review the native screenshots for affected states.
- The upload workflow enforces this: an unsigned `build.yml` run for another commit/branch cannot satisfy the release gate. The newest matching run must be complete and successful. A docs-only commit still needs CI if it is the commit you intend to upload; do not use `[skip ci]` on a release commit.
- Update `MARKETING_VERSION` in `project.yml` only when intentionally changing the app version. Routine uploads keep it and receive a new build number automatically.

## Upload and check Apple processing

1. Actions > **Upload to TestFlight** > **Run workflow** > branch `main`. Start one run.
2. If an environment reviewer is configured, approve the intended branch/commit in GitHub. Do not weaken the environment rules to bypass a failure.
3. The workflow checks exact-commit CI, then configuration, Swift tests, assets/project generation, signing profiles, archive contents, export and upload.
4. The build number is `GITHUB_RUN_NUMBER.GITHUB_RUN_ATTEMPT`. Do not hardcode it. A new run uses the current branch commit; rerunning an old workflow uses its old source.
5. Open App Store Connect > Apps > You Can't Park There > TestFlight > iOS. Wait for **Complete** processing and inspect any warnings/errors. A GitHub upload success alone is not Apple's acceptance.

The workflow uploads a beta, not a public App Store submission. A simulator `.app` or unsigned archive cannot be installed on the physical Watch.

## Make the processed build available

- In **Internal Testing**, use your existing personal testing group or create one if absent. The group needs **both your tester account and the processed build**.
- Add the new build and concise What to Test notes describing changed behavior. No duplicate App Store Connect user is needed for the Account Holder.
- If Apple asks for compliance/test information, answer for this binary. The project declares no non-exempt encryption; reassess that if encryption libraries are added.
- On the iPhone paired with your Watch, open Apple's TestFlight app and Install/Update this watch-only app. A separate iPhone app icon is not expected. Keep the Watch nearby and connected.
- Confirm the build actually opens on the Watch, then run the relevant entries in [DEVICE_TESTS.md](DEVICE_TESTS.md). Record build number, hardware, OS versions and results. Do not infer sensor/background/battery success from a simulator screenshot.

For a new internal build, useful What to Test text is: "Check the changed screens, real station freshness, permissions, complications, and Ride/End while safely stationary. Record Watch/iPhone versions and any failure." External testers have a separate review flow; do not grant administrative access merely to avoid it.

## Diagnose or roll back

Find the **first failed step**, not only the final exit code. Configuration/signing failures belong to [APPLE_SIGNING.md](APPLE_SIGNING.md); compiler and simulator failures do not get fixed by changing Apple accounts.

If Apple rejects processing, correct `project.yml` or source, rerun unsigned previews, then upload a new build. Preserve known-good keys/profiles unless the error actually concerns them. The archive validator guards the previously observed container motion-purpose-string rejection.

If a beta regresses, select an available prior build in TestFlight when offered, or revert the source change on a new commit, run CI and upload a new build. Do not force-reset shared history or reuse a previously uploaded build number. Keep a known-good preview baseline for comparison. TestFlight builds expire after 90 days; a later beta needs another upload, not another membership enrollment.
