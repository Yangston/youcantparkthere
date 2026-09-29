# Device acceptance checklist

Status: **not yet executed on Stone's physical watch**. Record watch model, watchOS/iOS versions, network path, build number, and results when testing. Never interact with the screen while moving through traffic.

| Test | Expected result | Result |
|---|---|---|
| Cold launch, Internet available | Real station names and timestamp, no sample data. | Not run |
| Deny location | Explicit downtown/no-GPS label; station browsing still works. | Not run |
| Grant location, fresh GPS | Nearby stations follow position; distances explicitly straight-line. | Not run |
| Deny motion | No crash; manual Ride works; permission status is understandable. | Not run |
| Find Docks / Find Bikes complication | Opens appropriate map mode. Does not advertise stale widget counts. | Not run |
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
