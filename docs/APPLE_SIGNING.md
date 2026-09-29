# Apple account and signing reference

The account, identifiers, app record and GitHub environment are already configured. Routine development does not repeat enrollment or recreate keys. The first successful processed beta was version 0.1.0, build 2.1; Stone subsequently confirmed it launched on the Watch. This is beta distribution, not a public App Store release.

## Three bundles, one app record

| Bundle | Default identifier | Purpose |
|---|---|---|
| ParkContainer | `com.yangston.youcantparkthere` | Non-launchable iOS watch-only distribution container |
| ParkWatch | `com.yangston.youcantparkthere.watchkitapp` | Actual native watchOS app |
| ParkWidgets | `com.yangston.youcantparkthere.watchkitapp.widgets` | Watch-face / Smart Stack launchers |

All three explicit identifiers belong to the same Apple team. App Store Connect has **one iOS app record**, using the root bundle identifier?even though this is a watch-only app. Its numeric Apple ID is **6817489933**. The chosen root must match `BUNDLE_ID`; child identifiers retain both suffixes.

Apple Developer ? Account manages membership, team, agreements, identifiers, certificates and profiles. App Store Connect manages the app record, API team keys, uploaded builds, TestFlight groups and testers. When there are multiple teams, select the same one in both sites.

## Two different private keys

| Material | What it does | Source / lifecycle |
|---|---|---|
| API private key `.p8` | Authenticates the CI signing/upload tools to App Store Connect | Downloaded once from Users and Access ? Integrations ? App Store Connect API ? **Team Keys**. Keep the original backup. |
| Distribution private key `.pem` | Matches the Apple Distribution certificate used to sign the binary | Generated locally with OpenSSL. The signing workflow retrieves/creates the matching certificate and provisioning profiles. Reuse it across updates. |

They are not interchangeable. A `.cer` certificate alone is not the distribution private key. Keep the full PEM text, with BEGIN/END lines and actual line breaks. A filename, base64 wrapper, Apple Account password, app-specific password, or two-factor code is not the requested value.

Use a **Team Key** with **App Manager** access for this workflow. Individual API keys do not support the provisioning endpoints it needs. Key ID identifies the particular API key; Issuer ID identifies its issuer; Team ID identifies the development team; numeric App Apple ID identifies the app record. They are different values.

## GitHub's protected `testflight` environment

Repository ? Settings ? Environments ? `testflight`. Deployment branch rules allow only branch `main`, with no tags. Signing material belongs exclusively in this environment's secrets, not source files or ordinary variables.

| Environment entry | Kind | Value |
|---|---|---|
| `APP_STORE_CONNECT_ISSUER_ID` | Secret | Issuer UUID matching the team API key |
| `APP_STORE_CONNECT_KEY_IDENTIFIER` | Secret | Ten-character API Key ID |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Secret | Complete `.p8` text |
| `CERTIFICATE_PRIVATE_KEY` | Secret | Complete distribution `.pem` text |
| `APPLE_TEAM_ID` | Variable | Ten-character Team ID from Apple Developer membership |
| `APP_STORE_APP_ID` | Variable | `6817489933` |
| `BUNDLE_ID` | Variable | Root identifier in the table above |

GitHub cannot reveal saved secret values. Reading back names proves configuration exists, not that Apple will accept it. `check_signing.py` validates presence/basic formats; actual signing validates API access and certificate/profile compatibility. The binary's Bundle ID selects the app record; `APP_STORE_APP_ID` is a recorded/preflight-checked identifier, not an override.

The open-source Codemagic CLI runs inside GitHub Actions; no Codemagic subscription or server is used. The public GBFS feed needs no Apple/API key. Development previews use no signing secrets.

## Recovery, only when needed

- **401:** verify `.p8`, Key ID and Issuer ID belong to the same active team key. A revoked key cannot be repaired by generating a new certificate key.
- **403:** check membership, accepted agreements, team selection and API role. Do not switch to an individual key.
- **Certificate quota:** deliberately reuse an existing matching private key or inspect unused certificates. Do not revoke certificates used by other apps.
- **Bundle/profile mismatch:** compare all three identifiers, Team ID and root `BUNDLE_ID`. The workflow obtains profiles; routine updates need no manual profile creation.
- **Lost/compromised API key:** revoke that key in Apple and replace its three GitHub entries with a newly downloaded matching team key. Never post keys in chat, issues, screenshots or logs.
- **Lost distribution key:** a certificate alone cannot restore it. Recover your private backup or intentionally create a replacement key/certificate; do not overwrite backups blindly.
- **Private local backups:** store outside this checkout (for example `~/.apple-signing/youcantparkthere/`) and protect them like passwords. Git ignore rules remain as a second guard against accidental commits, including old setup-bundle names.

## Packaging nuances that already mattered

Apple rejected build 1.1 with **ITMS-90683** because `ParkContainer.app` lacked `NSMotionUsageDescription`, even though the embedded Watch app had it. Keep the motion purpose string in **both container and watch** metadata in `project.yml`. The archive validator checks both before upload. Keep the Watch location purpose string and privacy manifest as well.

A green upload only means delivery succeeded. Apple processing can reject it afterward; verify the build in TestFlight. Build 2.1 was processed successfully after the container string was added. No extra permission capability or new key was needed for that fix.

Apple references: [App records](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app) ? [API team keys](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/) ? [Key restrictions](https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api) ? [Internal testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers) ? [TestFlight installation](https://testflight.apple.com/).
