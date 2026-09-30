# Device acceptance checklist

Status: **installation and initial launch confirmed by Stone on 29 September 2026**. Stone reported that the app works on the Watch after the first successful beta delivery. Exact installed build, Watch model and OS versions were not supplied; the individual acceptance tests below remain unverified. Record watch model, watchOS/iOS versions, network path, build number, and results when testing. Never interact with the screen while moving through traffic.

| Test | Expected result | Result |
|---|---|---|
| Install and initial launch | Native app installs and opens on the physical Watch. | Passed - user report, 29 September 2026; build/model/OS not supplied |
| Cold launch, Internet available | Real station names and timestamp, no sample data. | Not run |
| Deny location | GPS status is explicit in Settings; recenter opens the permission explanation. Station browsing still works. | Not run |
| Grant location, fresh GPS | Nearby stations follow position; distances update from GPS. | Not run |
| Deny motion | No crash; map browsing works; permission status is understandable. | Not run |
| Find Docks / Find Bikes complication | Opens appropriate map mode. Does not advertise stale widget counts. | Not run |
| Detected-cycling Smart Stack suggestion | Enable automatic cycling, wait for valid detection while the app is running, return to the clock, inspect Smart Stack with suggestions enabled. Record whether watchOS presents the shortcut/hint. Automatic stop/opt-out should withdraw relevance; no claim of closed-app cycling detection. | Not run |
| E-bike indicators and station details | Map bike totals, lightning indicators, and separate station-detail ordinary/e-bike counts match fresh operator data. Missing or stale type counts show unknown. | Not run |
| Full-screen map and compact markers | Map pans/zooms; markers and controls respond reliably. | User report, 30 September 2026: map works, button presses often do nothing. Exact build/hardware not supplied. Enlarged hit regions and safe-area fix await device retest. |
| One-finger swipe between Map and Settings | Swipe left across the bottom strip to Settings and right back; dragging the map still pans. No gear button. Verify mode, recenter and station taps. Start drags over the controls, empty bottom-strip space, and both page dots. | User report, 30 September 2026: previous version required two fingers; one finger panned the map. New separate strip awaits device retest. |
| Browse a different map region | Pan several kilometres through operator coverage; stations appear around the camera, rather than remaining tied to GPS. Pan back, zoom and confirm freshness/unknown states are preserved. | Not run |
| Compact update badge | Only data freshness is shown at the lower left. Location context and errors are available on Settings. | Not run |
| Detected cycling, lower/raise wrist | Test actual background-location and Return to Clock behavior. Record interruptions. | Not run |
| Recenter on open and repeated wake | With location allowed, open the app and verify centering. Pan away, lower/raise the wrist, and verify it follows the latest position again. Move roughly 1 km during detected cycling navigation and repeat; test with Always On enabled and disabled where supported. Confirm a delayed fresh GPS fix updates the center and denied/stale GPS is explained in Settings. | Not run |
| 15+ seconds of cycling while open and detection enabled | Switch to Park and start navigation only on sufficient classifier evidence, without a Start button. | Not run |
| Walking, car, TTC, standing still | No false cycling start; capture false positives without storing location history. | Not run |
| Stop at traffic signal | Short stops keep navigation active; three minutes of confident stationary activity stops it. | Not run |
| Disable automatic cycling, continue moving | Stops background navigation immediately, clears suggestion, and suppresses restart for five minutes. No End button is required. | Not run |
| Full/disabled station | Zero or unavailable; never offered as available parking. | Not run |
| Turn off network | Cached map remains; stale counts become unknown; no fabricated success. | Not run |
| Favorite/unfavorite and relaunch | IDs and white pin outlines persist after relaunch; unfavouriting removes the outline. | Not run |
| VoiceOver / large text / smallest supported display | Controls announced, counts understandable, no clipped essential actions. | Not run |
| Watch-only Wi-Fi, paired-phone Internet, cellular where supported | Measure feed/GPS performance on each available connection. | Not run |
| Other app, low power, workout running | Record OS behavior; app must not claim it can override it. | Not run |
| 30-minute ride | Record battery delta; compare browsing vs automatic cycling navigation. | Not run |
| 90-minute timeout | Navigation stops; explicit status; no indefinite location session. | Not run |
| Automatic stop after cycling | Walking/driving/running for 60 seconds stops navigation; ambiguous activity does not claim a definite stop. Record behavior while active and while backgrounded. | Not run |
| Thirty markers and tighter recenter | Dense regions render at most 30 nearest the map center; dragging changes the selection. Recenter restores the closer default zoom. | Not run |

Deterministic decoder, ranking, freshness, client, detector, and favourite persistence tests live in `Tests/ParkCoreTests`. CI compilation does not replace any device test above.
