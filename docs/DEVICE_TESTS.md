# Device acceptance checklist

Status: **installation and initial launch confirmed by Stone on 29 September 2026**. Stone reported that the app works on the Watch after the first successful beta delivery. Exact installed build, Watch model and OS versions were not supplied; the individual acceptance tests below remain unverified. Record watch model, watchOS/iOS versions, network path, build number, and results when testing. Never interact with the screen while moving through traffic.

| Test | Expected result | Result |
|---|---|---|
| Install and initial launch | Native app installs and opens on the physical Watch. | Passed - user report, 29 September 2026; build/model/OS not supplied |
| Cold launch, Internet available | Real station names and timestamp, no sample data. | Not run |
| Deny location | Explicit downtown/no-GPS label; station browsing still works. | Not run |
| Grant location, fresh GPS | Nearby stations follow position; distances explicitly straight-line. | Not run |
| Deny motion | No crash; manual Ride works; permission status is understandable. | Not run |
| Find Docks / Find Bikes complication | Opens appropriate map mode. Does not advertise stale widget counts. | Not run |
| Active-Ride Smart Stack suggestion | Start Ride (manual or foreground auto-detection), return to the clock, inspect Smart Stack with suggestions enabled. Record whether watchOS presents the shortcut/hint. End/disable should withdraw relevance; no claim of closed-app cycling detection. | Not run |
| E-bike toggle and station details | Bikes/all totals, lightning indicator, and e-bike-only counts match fresh operator data. Missing or stale type counts show unknown. | Not run |
| Full-screen map and compact markers | Map pans/zooms; small markers remain tappable; clock, controls, Ride/End and gear remain usable on the physical display. | Not run |
| Manual Ride, lower/raise wrist | Test actual background-location and Return to Clock behavior. Record interruptions. | Not run |
| 15+ seconds of cycling while open and detection enabled | Switch to parking and enter Ride only on sufficient classifier evidence. | Not run |
| Walking, car, TTC, standing still | No automatic Ride; capture false positives without storing location history. | Not run |
| Stop at traffic signal | Ride stays active. | Not run |
| End Ride, continue moving | Auto-start suppressed for five minutes; GPS stops after app backgrounds. | Not run |
| Full/disabled station | Zero or unavailable; never offered as available parking. | Not run |
| Turn off network | Cached map remains; stale counts become unknown; no fabricated success. | Not run |
| Target becomes full | One warning on fresh positive-to-zero transition; no repeated taps each refresh. | Not run |
| Within 60 m of chosen available target | One proximity haptic; no claim that the bike is returned. | Not run |
| Apple Maps handoff | Opens correct station coordinate/name; returning restores session state while process survives. | Not run |
| Favorite/unfavorite and relaunch | Favorite IDs persist. | Not run |
| VoiceOver / large text / smallest supported display | Controls announced, counts understandable, no clipped essential actions. | Not run |
| Watch-only Wi-Fi, paired-phone Internet, cellular where supported | Measure feed/GPS performance on each available connection. | Not run |
| Other app, low power, workout running | Record OS behavior; app must not claim it can override it. | Not run |
| 30-minute ride | Record battery delta; compare browsing vs Ride mode. | Not run |
| 90-minute timeout | Ride stops; explicit message; no indefinite location session. | Not run |

Deterministic decoder, ranking, freshness, client, detector, and target-alert tests live in `Tests/ParkCoreTests`. CI compilation does not replace any device test above.
