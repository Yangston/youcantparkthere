# Assisted Windows setup for stages 6 and 7

This supplements [SETUP.md](SETUP.md), not the Apple membership, app registration, or first-upload checks. The GitHub connector used in chat can edit repository files but does not expose Actions secret/environment administration. A private key supplied in chat has not automatically been stored in GitHub.

## What the helper does

`scripts/setup_testflight.ps1` runs on your Windows computer using your GitHub CLI browser login. It is deliberately restricted to `Yangston/youcantparkthere` and the `testflight` environment. It reads the Apple API key and the separate distribution private key from local files. Private-key contents are sent only to `gh secret set` through standard input: not committed, printed, placed on command lines, or uploaded as build artifacts.

The helper creates a missing environment with a main-only branch policy, preserves protection rules on existing environments, stores the Apple settings, and checks the resulting secret names and variable values. A preexisting environment-level or repository-level `CERTIFICATE_PRIVATE_KEY` is preserved rather than replaced with a new key. Existing Apple API secrets are intentionally updated to the supplied key and identifiers.

It does not create/revoke Apple certificates, purchase anything, start a workflow, submit an app, or invite testers. Secret values cannot be read back; confirmed names do not prove Apple permissions or a valid upload. The signed upload remains a separate step.

## With a private setup bundle

1. Extract the private bundle outside your repository. It contains an unencrypted signing private key; keep it private and do not upload the ZIP or folder to GitHub.
2. Review `Setup-TestFlight.ps1`, then run `Start-Setup.cmd`. The launcher uses a process-local PowerShell execution-policy option; it does not change your machine/user execution policy. Do not circumvent organization-managed execution restrictions.
3. Enter your **Apple Team ID**, select the original downloaded `AuthKey_....p8` file, and confirm the displayed repository and bundle ID. The Team ID is in Apple Developer > Account > Membership details; it is not your API Key ID, Issuer ID, or numeric app ID.
4. Install the official GitHub CLI when prompted, if needed. Complete GitHub browser login using an account with repository administration rights. No GitHub password or token belongs in chat.
5. Require the helper's `SUCCESS` message. If it stops, settings saved before the error remain saved; fix the named problem and rerun. Do not assume the whole setup completed after a partial failure.

The app's configured bundle ID must match the App Store Connect record. A generated key is not an issued Apple Distribution certificate; the existing TestFlight workflow obtains the matching certificate/profiles during signing.

## Without a bundle

Create a **local** `testflight-settings.json` outside the repository:

```json
{
  "repository": "Yangston/youcantparkthere",
  "environment": "testflight",
  "app_id": "YOUR_NUMERIC_APP_ID",
  "issuer_id": "YOUR_ISSUER_UUID",
  "key_id": "YOUR_KEY_ID",
  "bundle_id": "com.yangston.youcantparkthere"
}
```

Generate or reuse your signing private key using stage 6 in SETUP.md. Then run the reviewed helper from PowerShell with explicit local paths:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\scripts\setup_testflight.ps1 `
  -ConfigPath "$HOME\private-apple\testflight-settings.json" `
  -CertificateKeyPath "$HOME\private-apple\park_distribution_private_key.pem"
```

You may provide `-TeamId` and `-ApiKeyPath` to avoid prompts. `-ValidateOnly` checks configuration/key-file formatting without any API calls or writes; it is not a cryptographic key or Apple authorization check. The Windows CI workflow runs credential-free parsing/format tests, not a real secret upload.

## After successful setup

Open **Actions > Upload to TestFlight > Run workflow > main** and follow stages 8-10 in SETUP.md. Check the signing/upload result before moving to TestFlight installation. Existing environment reviewers or deployment restrictions may require approval or allow-list adjustment by the repository owner; the helper does not remove those protections.

Keep private backups of both original keys. Do not publish the setup bundle, include keys in screenshots, or upload private keys as Actions artifacts. If a key becomes exposed to an untrusted party, revoke and replace it through Apple; do not revoke unrelated distribution certificates.

References: [GitHub CLI secret encryption and standard input](https://cli.github.com/manual/gh_secret_set), [environment variables](https://cli.github.com/manual/gh_variable_set), [Apple Team ID](https://developer.apple.com/help/glossary/team-id/).
