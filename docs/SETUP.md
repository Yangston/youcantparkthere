# First-time setup: from Windows to your Apple Watch

This guide assumes you have **never made an iOS or watchOS app**. Follow it in order. You do not need to install Xcode, own a Mac, understand Swift, or manually create certificates in Xcode.

**Goal:** install this repository's watch app on your own Apple Watch through TestFlight. This is private beta testing, not a public App Store launch.

**Read this distinction first:** a green **Build and test** run means the code passed the checks in that run. It does **not** install the app, sign it with your Apple account, or prove that it works on a real watch. **Upload to TestFlight** is a separate, manually started workflow that needs the account setup below.

Guide updated: **29 September 2026**. Apple/GitHub screen labels can change; official references are linked at the relevant steps. Physical-device behavior and your account's first signed upload still require validation.

## Your path through the guide

| Stage | Do this where? | Result |
|---|---|---|
| [1. Check the code build](#1-check-the-code-build-before-paying-or-configuring-apple) | GitHub in your Windows browser | Know whether the code checks pass. |
| [2. Activate Apple membership](#2-activate-your-apple-developer-membership) | Apple website or Developer app | An account allowed to distribute TestFlight builds. |
| [3. Register identifiers](#3-register-the-three-bundle-identifiers) | Apple Developer website | Names Apple uses to identify the app's three bundles. |
| [4. Create the app record](#4-create-one-app-store-connect-record) | App Store Connect | The destination for uploaded builds. |
| [5. Make an API key](#5-create-a-team-api-key-for-github-to-talk-to-apple) | App Store Connect | Permission for the build machine to communicate with Apple. |
| [6. Make a signing private key](#6-create-the-signing-private-key-on-windows) | Git Bash on Windows | A private key for the app's distribution certificate. |
| [7. Save settings securely](#7-add-the-settings-to-this-github-repository) | GitHub repository settings | GitHub can use your signing settings without putting them in source code. |
| [8. Upload](#8-run-the-testflight-upload) | GitHub Actions | A signed build uploaded to Apple. |
| [9. Invite yourself](#9-make-the-build-available-to-yourself) | App Store Connect | Your Apple account is a tester for this build. |
| [10. Install and test](#10-install-on-your-watch) | Paired iPhone, then Watch | The app runs on your wrist. |

Stages 2–7 are normally **one-time setup**. Routine updates use stages 8–10. Keep using the same Apple membership and identifiers; you do not purchase a membership per app.

## 0. What you need, and what the terms mean

Have your Windows computer, GitHub login, iPhone, and paired Apple Watch available. This project's minimum targets are **watchOS 10** and an **iOS 17** watch-only distribution container. Check the watch under Settings → General → About and the phone under Settings → General → About. Your devices also need to be compatible with each other and with the current TestFlight app.

The setup has three different websites/services:

| Name | Plain-English meaning |
|---|---|
| **GitHub repository** | Our source-code folder: [Yangston/youcantparkthere](https://github.com/Yangston/youcantparkthere). |
| **GitHub Actions / workflow** | A saved sequence of commands that GitHub runs on a temporary computer. Our native builds use a macOS computer hosted by GitHub. |
| **Apple Developer account** | Where you manage membership, bundle identifiers, certificates, and profiles. |
| **App Store Connect** | Apple's dashboard for app records, uploaded builds, and TestFlight testers. It is separate from the Developer account dashboard. |
| **TestFlight** | Apple's beta-installation app. It gets the signed build from Apple to your device. |
| **Bundle ID** | A unique, dot-separated identifier, such as `com.yangston.youcantparkthere`. Not your email or app's display name. |
| **Signing** | Attaching a verifiable developer signature to an app. The workflow handles the certificate/profile steps after you provide credentials. |
| **Secret** | A protected value stored in GitHub settings. Never a source-code file. |

This is a **watch-only app**. Its small iOS container exists for distribution; there is no separate iPhone interface to open. Apple treats watch-only apps as **iOS** when you create their App Store Connect record. [Apple's app-record instructions](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app)

For this TestFlight route, you need a paid Apple Developer Program membership. Apple lists **US$99 per year**, with regional/local-currency pricing shown during enrollment. Do not interpret that as CAD$99. Free learning and some Xcode-based personal-device testing are different from this TestFlight route. [Membership comparison](https://developer.apple.com/support/compare-memberships/)

A Codemagic subscription is **not** part of this setup: the workflow runs the open-source Codemagic signing command-line tools inside GitHub Actions. Check your GitHub plan's Actions usage/billing before running many builds; do not change repository visibility just to follow this guide.

## 1. Check the code build before paying or configuring Apple

1. Open [the repository](https://github.com/Yangston/youcantparkthere) and make sure you are signed in as an account with access.
2. Click **Actions** near the top, then **Build and test** in the left sidebar.
3. Open the most recent run for **main**. Old red runs describe older code; they do not change retroactively when a fix is committed.
4. Read the run's **What this run checked** summary. Click the **watch** job to expand individual steps.
5. For a new manual run, return to **Build and test**, click **Run workflow**, select branch **main**, then click the confirmation **Run workflow** button. Start one run, not several. [GitHub's instructions](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)

| Check in this repository | What passing establishes |
|---|---|
| CI helper tests | The Python test harness handles its tested inputs/errors correctly. |
| Portable Swift tests | Station decoding/filtering/freshness, ride logic, and route parsing pass deterministic tests. |
| Watch + widget compilation | Apple's compiler accepts the native app and watch-face widget code. |
| Unsigned packaging | The distribution archive contains the expected watch-only container, watch app, widgets, and metadata. |
| Live feed (diagnostic) | The operator's feed was reachable and usable at that time. A remote outage is reported separately. |
| Paired simulator launch + in-app route state | The app installs, stays running, and reaches the expected Park/Bikes/Ride states using a simulator-only test hook. |

**Not covered by those checks:** Apple signing, TestFlight acceptance, a real complication tap delivering its URL, physical GPS/motion, or background wrist-raise behavior. Simulator routing uses the same production handler but is not an end-to-end test of watchOS dispatch.

For screenshots/logs, open a completed run's **Summary**, scroll to **Artifacts**, download **watch-build**, and extract the ZIP in Windows. `demo-docks.png`, `demo-bikes.png`, and `demo-ride.png` are explicitly labeled sample-data screenshots. `simulator-smoke.log` explains launch checks; `tests.log` explains Swift tests. The simulator `.app` is **not** something you can install on a real watch.

**Checkpoint:** understand the newest run's result before continuing. You can do this entire stage without Apple credentials. Apple enrollment will not fix a compiler or simulator failure.

## 2. Activate your Apple Developer membership

Skip enrollment if you already have an active membership for another project, such as Wizardry.

1. Open [Apple Developer enrollment](https://developer.apple.com/programs/enroll/).
2. Sign in with the Apple Account you intend to use for development. Enable two-factor authentication if Apple requires it.
3. For a personal project under your own name, choose **Individual**. Do not choose Enterprise. Use your legal name and follow Apple's identity checks.
4. Read the price and agreement before buying. Complete enrollment, then wait for Apple to confirm that membership is active.
5. Open [Apple Developer → Account](https://developer.apple.com/account). Accept any required current agreements.
6. In your membership information, locate your **Team ID**. It is ten letters/digits. Copy it into a private setup note labeled `APPLE_TEAM_ID`.
7. Open [App Store Connect](https://appstoreconnect.apple.com/) with the same development account. Confirm that you can access **Apps** and **Users and Access**. When you belong to multiple teams, select the same team in both portals.

The Team ID is **not** your email, enrollment/order number, or the numeric ID of an app. An illustrative format is `A1B2C3D4E5`; use your actual value, never the example.

If your membership is pending or an agreement blocks access, resolve that with Apple before creating keys. Do not make a second account as a workaround. [Apple enrollment requirements](https://developer.apple.com/help/account/membership/program-enrollment)

**Checkpoint:** active membership, working App Store Connect access, and your Team ID recorded. No app code changes needed.

## 3. Register the three bundle identifiers

Use the defaults below unless Apple says the identifier is already registered to another team. These must match exactly across Apple and our build configuration.

In [Apple Developer → Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list), open **Identifiers**. For each row below:

1. Click **+** to register an identifier.
2. Choose **App IDs**, continue, then choose **App** if asked for the type.
3. Enter the description from the table. Select an **Explicit** Bundle ID, not a wildcard.
4. Paste the corresponding bundle identifier. Leave optional capabilities at their defaults; this project does not need HealthKit, Push Notifications, or App Groups.
5. Continue, review, then **Register**. Repeat for the other two rows.

| Description you can enter | Explicit Bundle ID to paste |
|---|---|
| You Cant Park There Container | `com.yangston.youcantparkthere` |
| You Cant Park There Watch | `com.yangston.youcantparkthere.watchkitapp` |
| You Cant Park There Widgets | `com.yangston.youcantparkthere.watchkitapp.widgets` |

The root is the distribution package; the second is the actual watch app; the third is the watch-face/Smart Stack widget extension. These are **three identifiers**, not three App Store app records. Location and motion permission text is already in the project. [Apple identifier instructions](https://developer.apple.com/help/account/identifiers/register-an-app-id/)

An identifier already present under **your own team** can be reused. Do not delete it to make this guide's screens match. When a default identifier belongs to someone else, choose a unique root such as `com.youruniquehandle.youcantparkthere`, register that root and its two matching suffixes, and use that root as `BUNDLE_ID` in stage 7. Do not change only one of the three.

**Checkpoint:** all three identifiers are visible under the correct Apple team. Do not manually create provisioning profiles yet; the workflow handles them.

## 4. Create one App Store Connect record

1. Open [App Store Connect](https://appstoreconnect.apple.com/) → **Apps**.
2. Click **+** → **New App**.
3. Complete the form as follows, then click **Create**.

| Field | What to enter |
|---|---|
| Platforms | **iOS**, including for this watch-only app. |
| Name | `You Can't Park There`; if unavailable, use another available name, such as `Stone Parking`. |
| Primary Language | Your intended language, for example **English (U.S.)**. |
| Bundle ID | The **root** identifier from stage 3, not either `.watchkitapp` identifier. |
| SKU | A unique internal label, for example `youcantparkthere-001`. This is not a password. |
| User Access | **Full Access** is straightforward for your own individual account; use your team's access policy for a shared account. |

4. Open the newly created app, then **General → App Information**.
5. Find **Apple ID**, the app's numeric identifier, and record it as `APP_STORE_APP_ID`. This is a number, not your Apple Account email or Team ID.
6. Record the root Bundle ID beside it so you can cross-check later.

[Apple's new-app instructions](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app)

Do not create three app records. Do not click **Submit for Review** to the public App Store. An empty app record or **Prepare for Submission** status is normal here. Store screenshots, marketing text, and a public release are not the goal of this walkthrough. Your record must exist before the first upload. [App Store Connect workflow](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-workflow)

**Checkpoint:** one app record with the root Bundle ID and a numeric Apple ID.

## 5. Create a team API key for GitHub to talk to Apple

There are **two different private keys** in this guide. This stage creates the Apple **API key** (`.p8`). Stage 6 creates the **certificate signing key** (`.pem`). They are not interchangeable.

1. In App Store Connect, open **Users and Access → Integrations → App Store Connect API**.
2. If **Request Access** appears, the Account Holder must request API access and wait for approval.
3. Select **Team Keys**, not Individual Keys. Individual keys cannot use Apple's provisioning endpoints needed by this workflow.
4. Click **Generate API Key** or **+**. Name it `YouCantParkThere GitHub`.
5. Select **App Manager** access, the role recommended for this signing approach by Codemagic, then generate the key. Creating team keys requires Account Holder or Admin access.
6. Record its **Key ID** and the team's **Issuer ID**. Keep these labels distinct from Team ID.
7. Click **Download API Key**. Save the `.p8` file somewhere private outside your repository. Apple only permits this download once.

[Apple API access and team-key steps](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/) · [Apple key security and provisioning restrictions](https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api) · [Codemagic role/signing guidance](https://docs.codemagic.io/yaml-code-signing/alternative-code-signing-methods/)

| Value you now have | GitHub secret it will become |
|---|---|
| Issuer ID from the team API page | `APP_STORE_CONNECT_ISSUER_ID` |
| Key ID for this particular key | `APP_STORE_CONNECT_KEY_IDENTIFIER` |
| Entire contents of the downloaded `.p8` file | `APP_STORE_CONNECT_PRIVATE_KEY` |

A filename like `AuthKey_XXXXXXXXXX.p8` is **not** the secret value. You will copy its contents, including the `BEGIN PRIVATE KEY` and `END PRIVATE KEY` lines. Open it using **Open with → Notepad**, rather than assuming Windows knows what a `.p8` file is.

Team keys have access across apps according to their role. Treat this as real access to your developer account. Never upload the file to chat, commit it, include it in a screenshot, or paste it into an issue. GitHub cannot reveal a saved secret later; keep a secure backup. Revoke a compromised API key in Apple and replace the corresponding GitHub secrets.

**Checkpoint:** the `.p8` file is safely stored, and its matching Key ID and Issuer ID are available.

## 6. Create the signing private key on Windows

This key is used to create or retrieve a matching Apple Distribution certificate. It does not come from the API-key download page. The workflow then obtains signing profiles for our three bundles. [How this signing method works](https://docs.codemagic.io/yaml-code-signing/alternative-code-signing-methods/)

Already have the private key matching an existing distribution certificate? Reuse it rather than generating another one. A `.cer` certificate file alone is not the private key. Do not revoke certificates used by your other projects.

For a new key:

1. Install **Git for Windows** from [the official download page](https://git-scm.com/install/windows) if you do not already have Git Bash. Normal installer defaults are sufficient for this task.
2. Open the Windows Start menu and launch **Git Bash**. The commands below are for Git Bash, not PowerShell or Command Prompt.
3. Type this, then press Enter:

```sh
openssl version
```

You should see an OpenSSL version. If the command is not found, stop and check that you opened Git Bash from your Git for Windows installation; do not download an arbitrary key-generation website/tool.

4. Paste this block. It makes a private-key folder outside the repository and **will not overwrite an existing key**:

```sh
umask 077
mkdir -p "$HOME/.apple-signing"
cd "$HOME/.apple-signing"
if [ -e park_distribution_private_key.pem ]; then
  printf 'Key already exists; keeping it. Do not replace it accidentally.\n'
else
  openssl genrsa -out park_distribution_private_key.pem 2048
fi
openssl pkey -in park_distribution_private_key.pem -check -noout
```

A successful validity check means the key was generated/read, not that Apple has issued its certificate yet. No private key text should be printed. Keep the file in a secure location; Windows folder permissions and your device security still matter.

5. To copy the key into the GitHub secret field in stage 7 without printing it to the terminal, run:

```sh
clip.exe < "$HOME/.apple-signing/park_distribution_private_key.pem"
```

This copies the complete file into your Windows clipboard. Paste it only into the **secret value** field. Avoid clipboard-history/sync tools for this operation. After saving the secret, clear the current clipboard:

```sh
printf '' | clip.exe
```

Clearing the current clipboard does not erase copies previously kept by clipboard-history software. Store a secure backup of the original key rather than relying on the clipboard or GitHub to recover it.

**Checkpoint:** you have both the `.p8` API key and the separate `.pem` certificate key. Neither is in the repository. You do not need to install Python, Swift, Xcode, or the signing CLI on Windows for the hosted build.

## 7. Add the settings to this GitHub repository

Use **this repository's Settings**, not your GitHub profile settings and not another project's secrets.

### 7A. Create the `testflight` environment

1. Open [Yangston/youcantparkthere](https://github.com/Yangston/youcantparkthere) → **Settings → Environments**.
2. Click **New environment**, enter exactly `testflight`, then **Configure environment**. Open it directly instead if it already exists.
3. Under deployment branches/tags, choose **Selected branches and tags**. Add a **Branch** rule for `main`.
4. An approval requirement is optional. For a solo setup, avoid a rule that prevents you from approving your own run unless another trusted reviewer is available.

Public repositories support environments on current GitHub plans. Private-repository environment support depends on the plan; if this section is unavailable, check your access/plan rather than moving keys into code or changing repository visibility. [GitHub environment documentation](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments)

### 7B. Add FOUR environment secrets

Inside `testflight`, find **Environment secrets → Add secret**. Add each row separately. Copy the name exactly; paste only the value, with no surrounding quotes. Save each before starting the next.

| Secret name — exact spelling | Value to enter |
|---|---|
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID from stage 5. |
| `APP_STORE_CONNECT_KEY_IDENTIFIER` | Key ID from stage 5. |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Complete `.p8` text from stage 5, including both boundary lines. |
| `CERTIFICATE_PRIVATE_KEY` | Complete `.pem` text from stage 6, including both boundary lines. |

For multiline keys, paste the real line breaks. Do not convert them to literal `\n`, encode as base64, paste the file's path, or paste only the middle of the key. A `.p8` key commonly starts with `-----BEGIN PRIVATE KEY-----`; the generated certificate key may use that header or `-----BEGIN RSA PRIVATE KEY-----`. Both are private key formats; use the correct file for each row.

### 7C. Add environment VARIABLES, in the other section

Below the secrets section, find **Environment variables → Add variable**. These are identifiers, not private key material.

| Variable name | Value to enter |
|---|---|
| `APPLE_TEAM_ID` | Your actual ten-character Team ID from stage 2. |
| `APP_STORE_APP_ID` | Your actual numeric app Apple ID from stage 4. |
| `BUNDLE_ID` | `com.yangston.youcantparkthere`, or your custom root from stage 3. |

`BUNDLE_ID` is technically optional because the workflow has the displayed default, but adding it makes the setup explicit. The other two variables are required by the current preflight. The uploaded binary's Bundle ID selects the App Store Connect app; the numeric `APP_STORE_APP_ID` is currently a recorded/preflight-checked identifier, not an override of that selection.

**Checkpoint:** the environment shows **four secret names** and **three variable names**. The two private keys must not appear in the variables section. Confirm the three Apple identifiers all start with the `BUNDLE_ID` you entered.

Do not use an Apple Account password, an app-specific password, a six-digit login code, or an OpenAI API key for any of these fields. None is requested by this workflow.

## 8. Run the TestFlight upload

Before starting, make sure the newest code checks passed and stages 2–7 are complete. This operation may create signing resources in your Apple team and will upload a beta; it is not just a dry run.

1. In the repository, open **Actions → Upload to TestFlight**.
2. Click **Run workflow**, select **main**, and confirm **Run workflow**.
3. Open the new run. If an environment approval is requested, use **Review deployments** and approve only after confirming the branch/commit.
4. Open the **distribute** job to follow progress. Do not start another upload just because Apple or a runner is taking time.

| Step | What the workflow does | A failure here usually means |
|---|---|---|
| Validate configuration without printing secrets | Checks required names and basic formats. | A missing/misplaced secret/variable or wrong value format. |
| Install build tools | Uses GitHub's macOS runner to install XcodeGen and signing tools. | Runner/network/tooling problem; not necessarily your account. |
| Test and generate project | Runs Swift tests and produces the Xcode project from `project.yml`. | Code or project-generation problem. |
| Fetch signing assets | Authenticates to Apple, retrieves/creates matching certificates and profiles, and configures signing. | Wrong API key/team/role, pending agreement, identifier mismatch, or certificate limit. |
| Archive and export | Compiles a signed release and packages it as an `.ipa`. | Signing/profile/entitlement or build issue. |
| Upload for testing, not public release | Sends the `.ipa` to App Store Connect. | Upload validation, access, or missing app-record issue. |

The build number is generated by the workflow from its run number/attempt. Do not edit build numbers manually for normal retries. A green upload is still followed by Apple's processing; it does not automatically invite testers or submit a public release.

When it fails, open the **first failed step** and note the actual message, not just the final `exit code 1`. Check stage 12 before regenerating anything. Avoid sharing full logs without reviewing them for credentials/account details.

**Checkpoint:** upload step succeeds. Next use Apple's dashboard, not a downloaded GitHub simulator app.

## 9. Make the build available to yourself

1. Open App Store Connect → **Apps → your app → TestFlight**.
2. Look under the **iOS** builds/version section. Wait for the uploaded build to finish processing. This is separate from GitHub's completed upload.
3. Resolve any **Missing Compliance**, agreements, or test-information requests. Read the questions accurately: this app uses Apple's networking/HTTPS, and its current project declares no non-exempt encryption. Reassess that declaration when adding encryption libraries; do not blindly answer every encryption question “No.”
4. For the first test, choose **Internal Testing**, not a public testing link. Click **+** beside Internal Testing and create a group called `Personal testing`.
5. Leave automatic distribution off for the first run so you explicitly choose the build.
6. In the group, click **Invite Testers**, select your own eligible App Store Connect user, and add it.
7. Click **Add Builds**, choose the processed build, continue, and enter the What to Test text below. Save/add the build.

```text
Check nearby station loading, Park/Bikes switching, permission prompts, and
manual Ride/End while stopped safely. Test Find Docks and Find Bikes from
a real complication. Report watch/iPhone OS versions and any failure.
Do not treat a proximity haptic as confirmation that a bike was returned.
```

[Apple's internal-testing instructions](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers)

The group needs **both a tester and a build**. Creating only one will not make the app appear. Your own Account Holder user can be an internal tester; there is no need to add a duplicate user. A school-managed Apple Account may not be eligible, so use the development/tester account intended for this setup.

External testers follow a different review/distribution process. Start with yourself; do not grant friends administrative access just to avoid external TestFlight review. [Apple external-testing guidance](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers)

**Checkpoint:** your group lists your user and the build; the tester invitation/build is available.

## 10. Install on your watch

1. On the **iPhone paired with your Watch**, open the App Store and install Apple's **TestFlight** app.
2. Open your tester invitation on that phone and tap **View in TestFlight**. Accept the invitation.
3. In TestFlight's Apps list, tap **Install** for this watch-only app. Apple's instructions distinguish this from an iPhone app with a watch companion; our app is the watch-only case.
4. Keep the watch nearby, connected, and unlocked while installation completes.
5. On the watch, press the Digital Crown to open the app list/grid and find **You Can't Park There**. A separate iPhone Home Screen app is not expected.

[Apple's watchOS TestFlight installation instructions](https://testflight.apple.com/)

No device UDID registration or manual provisioning-profile installation is part of this TestFlight route. [Apple TestFlight overview](https://developer.apple.com/testflight/)

If you are offered no installable build, first check the tester invitation, group/build assignment, processing/compliance status, and device compatibility. Downloading the `.app` from GitHub is not a substitute.

**Checkpoint:** the native app opens on the Watch itself. That is the first real-device milestone.

## 11. First-use test, while safely stationary

Open the app and grant location permission when prompted. Initially leave automatic cycling detection off. Confirm that actual station names appear, the timestamp is recent, and the screen does **not** say DEMO. With no location fix, downtown browsing is labeled explicitly.

Switch **Park / Bikes** using the top control, then swipe to the nearby list and settings. Select a station, try favoriting it, return to the map, and test **Ride → End**. Availability can change; the app does not reserve a dock, unlock a bike, or confirm its return.

Add **Find a Dock** and **Find a Bike** to suitable watch-face complication slots or the Smart Stack. Tap each and verify it opens the correct mode. This is important: CI checks in-app routing, **not** the system's real complication-to-app delivery. Record any incorrect mode or failure to open.

For ride behavior, start Ride while stopped, then test lowering and raising your wrist. In Watch Settings → General → Return to Clock, select this app and review **After 1 hour**. This is a user preference, not a guarantee that the app overrides other apps or watchOS power behavior. Optional cycling detection works only while this app is executing/open; it cannot launch a closed app. End rides manually.

Record results in [DEVICE_TESTS.md](DEVICE_TESTS.md), including watch model, watchOS version, iOS version, build number, and what happened. Do not mark unperformed tests as passed. Check GPS/background/motion and battery on hardware before relying on the app during travel. Stop safely before touching the display.

## 12. Troubleshooting by where you got stuck

| What you see | Next action |
|---|---|
| Old red runs remain | Open the newest run for the newest commit. History is not rewritten. Do not rerun old code expecting it to include the fix. |
| New Build and test run is red | Open the first failed step and the summary. No Apple account setting can repair a Swift compiler error or simulator crash. |
| OSStatus -10814 in an old smoke run | That old test tried generic `simctl openurl` after a successful launch. The new test asserts the app's route state instead; actual complication delivery remains a device test. |
| No GitHub Settings/Environments or Run workflow button | Confirm owner/write access, the correct repository/workflow, and environment availability for your GitHub plan. |
| Missing configuration: a list of names | Add those exact entries to this repo's `testflight` environment. Match secrets vs variables. Values in Wizardry's environment do not automatically carry over. |
| Private-key format error | Check the correct file's complete text, BEGIN/END lines, and real line breaks. Do not paste base64, a pathname, or the other private key. |
| Apple 401 / invalid credentials | Check that Issuer ID, Key ID, and `.p8` all belong to the same active team key. Check revocation; do not regenerate the certificate key first. |
| Apple 403 / forbidden | Check active membership/agreements and the team API key's role. An individual API key is not suitable for provisioning. |
| Certificate quota/limit reached | Reuse a matching existing distribution private key or inspect unused certificates deliberately. Do not revoke certificates blindly. |
| No matching provisioning profile / bundle mismatch | Compare the root and both child identifiers with the chosen Apple team and `BUNDLE_ID`. Copy the full first error. |
| No suitable app record / bundle not found during upload | Stage 4 must use the root Bundle ID under the same team, not the watch/widgets ID. |
| Upload green, build absent on phone | Check Apple processing, compliance, internal group, assigned build, invited tester, and acceptance. Upload alone is not installation. |
| No iPhone icon | Expected: this app is watch-only. Open it on the Watch. |
| Dashes instead of counts | Unknown/stale/closed station is intentionally not reported as available. Check network and timestamps. |
| Map is downtown, not where I am | Check location permission and GPS label. The default without a fix is Toronto downtown. |
| Cycling does not automatically open the app | Expected for a closed app. Launch with a complication and start Ride manually. |
| A complication opens the wrong page | Record which complication, watchOS version, and build; this is a runtime bug to investigate, not an Apple-signing issue. |

For help, provide the **run link, failing step, and short error excerpt**, or a screenshot with keys/account details hidden. Never attach `.p8`, `.pem`, `.p12`, passwords, login codes, or full environment values. Public repository issues and screenshots are public.

## 13. Updating the app after the first successful installation

After a code change is committed to `main`, check **Build and test** for that commit. Then manually run **Upload to TestFlight**, let Apple process the new build, add it to your internal group, and use **Update** in TestFlight. You can enable automatic distribution/updates later once the first manual cycle is clear.

You normally keep the existing membership, three bundle identifiers, app record, four secrets, and variables. Do not repeat enrollment or create new API/certificate keys for each update. TestFlight builds last for up to **90 days**; upload a new build to keep beta testing beyond an individual build's lifetime. [Apple testing and expiry guidance](https://testflight.apple.com/)

### Final checklist

- [ ] Newest code checks reviewed; simulator checks are not confused with device testing.
- [ ] Apple membership active and correct team selected.
- [ ] Three bundle identifiers registered; one root app record created.
- [ ] Team API key and separate distribution private key stored securely.
- [ ] Four environment secrets and three environment variables saved in this repo.
- [ ] Manual TestFlight upload succeeded and Apple processed the build.
- [ ] Internal group has both my tester account and the build.
- [ ] App installed on the Watch through the paired iPhone's TestFlight.
- [ ] Real complication taps, permissions, and Ride/End checked; remaining device tests recorded honestly.
