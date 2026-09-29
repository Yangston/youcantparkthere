# Get it onto your watch — Windows + cloud builds

## 1. Confirm the code builds

Open this repository's **Actions → Build and test**. It runs deterministic Swift tests, builds the watch app and widget extension for the simulator, and validates an unsigned distribution archive. `watch-build` contains logs and the simulator app. The external live-feed check is diagnostic and does not make deterministic tests flaky.

No Apple membership or signing credentials are needed for this CI build. The simulator app is not installable on hardware.

## 2. Register the app with Apple

For this TestFlight path, use an active Apple Developer Program membership with App Store Connect access. You can do the account work in a browser on Windows.

Register these explicit bundle identifiers in Certificates, Identifiers & Profiles:

| Target | Default identifier |
|---|---|
| Watch-only distribution container | `com.yangston.youcantparkthere` |
| Watch application | `com.yangston.youcantparkthere.watchkitapp` |
| Widget extension | `com.yangston.youcantparkthere.watchkitapp.widgets` |

Create an **iOS** app record in App Store Connect using the container identifier. The app is watch-only; the iOS container is distribution packaging, not an iPhone user interface. Record its numeric Apple app ID. Use a unique app name if the preferred name is taken.

The project has no HealthKit, push, or App Groups entitlement. Location and Motion usage strings are already included. Do not add unrelated capabilities to obtain background execution.

A custom `BUNDLE_ID` is supported, but the root identifier in App Store Connect and both child identifiers must match that prefix exactly.

## 3. Configure the repository, not the source code

Create a GitHub **environment** named `testflight` under Settings → Environments. Restrict it to `main`, and use an approval rule when available. Store the following as environment secrets:

| Secret | Value |
|---|---|
| `APP_STORE_CONNECT_ISSUER_ID` | Team API issuer ID from App Store Connect. |
| `APP_STORE_CONNECT_KEY_IDENTIFIER` | The API Key ID. |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Complete downloaded `.p8` key contents, including BEGIN/END lines. |
| `CERTIFICATE_PRIVATE_KEY` | Complete RSA private key used for the Apple Distribution certificate. This is **not** the `.p8` API key. |

Add these environment variables (Settings → Environments → testflight → Environment variables):

| Variable | Value |
|---|---|
| `APPLE_TEAM_ID` | Your 10-character Apple Developer team ID. |
| `APP_STORE_APP_ID` | Numeric ID of the App Store Connect record you created. |
| `BUNDLE_ID` | Optional; defaults to `com.yangston.youcantparkthere`. |

Create the API key in App Store Connect → Users and Access → Integrations → App Store Connect API. Use a team key authorized for signing-resource management and uploads; Codemagic documents App Manager access. The key can be downloaded only once. Keep it in a secure private location.

For a new certificate private key, run this locally from a terminal with OpenSSL (for example Git Bash on Windows):

```sh
openssl genrsa -out park_distribution_private_key.pem 2048
```

Paste the complete PEM contents into the **secret** field, then store the file securely outside the repository. The workflow can create an Apple Distribution certificate matching it. An existing matching private key can be reused; avoid creating a new key on every run, and do not revoke other apps' certificates to get around a certificate limit.

**Never put private keys in a commit, issue, chat, README, variable field, or build artifact.** These are GitHub *secrets*, not plain variables. The workflow uses Codemagic's open-source CLI inside GitHub Actions; a Codemagic hosted account is not required.

## 4. Upload and install

Go to **Actions → Upload to TestFlight → Run workflow → main**. The workflow validates configuration, tests code, creates the project, obtains profiles for all three identifiers, signs, archives, exports an IPA, and uploads to App Store Connect. It may create Apple signing resources. It does not submit a public App Store release or automatically invite external testers.

After Apple processes the upload, resolve any compliance prompts, create/select an internal testing group, add yourself, and assign the build. Open TestFlight on the iPhone paired with your Apple Watch and use its watch-app installation control. Keep the watch connected and unlocked during installation. The exact label can vary with the TestFlight version.

The project targets watchOS 10+ with an iOS 17+ packaging container. Test on the OS versions actually installed on your devices. This cloud route avoids local Xcode and a local Mac, but does not remove Apple's signing requirements.

## 5. First ride

Open the app on your watch. Enable location or choose **Browse downtown**. The default page shows empty docks. Tap **Ride** while stopped to begin the navigation session; tap **End** after returning your bike. Location tracking stops outside an active ride when the app is backgrounded.

Add **Find a Dock** to a compatible watch-face complication slot or Smart Stack. In Watch Settings → General → Return to Clock, choose this app and set **After 1 hour** for the longest normal return behavior. An active location navigation session can also support wrist-raise return. Neither mechanism overrides an explicit app switch or guarantees a permanently lit screen.

Cycling detection is optional under Ride & settings. It requires motion permission and an available activity classifier. It only reacts while this app is open and does not launch it from the background. Manual Ride remains the reliable entry point.

## Troubleshooting

| Symptom | Check |
|---|---|
| Signing preflight names missing settings | Add them to this repo's `testflight` environment, not only the Wizardry repo. |
| Bundle identifier / profile mismatch | Match the root, `.watchkitapp`, and `.watchkitapp.widgets` identifiers and Apple team. |
| Signing says certificate quota exceeded | Use an existing matching distribution private key; do not revoke unrelated certificates. |
| TestFlight says no app record | Create the App Store Connect iOS record for the root bundle ID. |
| No stations or all dashes | Check Internet connectivity, timestamps, and `build/live-feed.log`. No network is replaced with fake stations. |
| Map centered downtown | Grant location permission. The label tells you when no current GPS fix is available. |
| Auto detection does nothing | Open the app, opt in, authorize Motion & Fitness, and check the status text. Real watch testing is required. |
| Watch returns to clock | Check Return to Clock settings and that a Ride session is active. Apps cannot force themselves to the foreground indefinitely. |
| GitHub build succeeds but device fails | Unsigned compilation and packaging are different from signed hardware installation. Use the signing/archive logs and device test checklist. |

References: [Apple TestFlight](https://developer.apple.com/testflight/), [Codemagic CLI signing](https://docs.codemagic.io/yaml-code-signing/alternative-code-signing-methods/), [Apple background sessions](https://developer.apple.com/documentation/watchkit/enabling-background-sessions).
