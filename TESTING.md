# Test and acceptance checklist

Run Flutter analysis/tests, backend policy tests and Firestore emulator tests as documented in README. Automated test results are recorded in BUILD_REPORT.md after execution.

## Real-device checks (not replaced by demo tests)

| Scenario | Expected |
|---|---|
| Register / sign in / reset / sign out | Real Firebase identity; useful failures; sign-out revokes shares |
| Permission granted | Device fix and uncertainty circle; true timestamp |
| Denied / permanently denied | Explanation and Settings/retry; map search still usable |
| GPS off / unavailable | No fake location; clear error |
| Approximate location / poor accuracy | Accuracy warning; no precision claims |
| Verified place search | Matching record selected on map |
| Missing geometry / graph | No invented boundary or route |
| Floors / QR | Only verified floors; wrong, demo-in-live and unknown QR rejected; stale after TTL |
| Sharing with two signed-in accounts | Only invited, accepting friend reads latest fix |
| Third account / admin | No private location read |
| Stop / block / expiry | Listener loses access; marker removed |
| Offline / delayed upload | Stale timestamp; outdated fix rejected server-side |
| Background / navigation away | Tracking stream stops; last fix becomes stale |
| Account deletion | Recent sign-in required; relationships and shares removed |
| Accessibility | Large text, screen reader, contrast, portrait/landscape, smallest supported phone |

Run two Android emulators or physical phones. Use 10.0.2.2 as EMULATOR_HOST for an Android emulator; use your computer's reachable LAN address for a physical phone. Do not use these tests to infer centimetre accuracy or hardware-assisted floors.
