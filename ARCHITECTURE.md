# Architecture

Flutter / Dart Android-first client, with a browser presentation build. Riverpod owns mode, theme and search state; go_router owns navigation. Firebase is initialized only when all required options are supplied. Missing configuration leaves the demo usable.

| Layer | Files | Responsibility |
|---|---|---|
| Domain | `lib/domain/campus.dart` | Dijkstra, accessible edges, QR validation/expiry, map records, floor transforms, boundary classification |
| Data | `lib/data/services.dart` | Firebase configuration, repository, graph parsing, foreground Geolocator subscription |
| Application | `lib/application/app_state.dart` | Riverpod mode/search/theme state |
| Presentation | `lib/presentation/` | Onboarding, map, indoor, social, settings, admin |
| Server | `functions/index.js` | Authenticated friendship, invitation, location publication, revocation, deletion and retention |
| Authorization | `firestore.rules` | Private owner/viewer access, expiry, admin-only map changes, deny by default |

## Location flow

Device permission → Geolocator position stream → accuracy/time checks → map state. Sharing uses a separate service instance with an explicit active session. Server rejects old, invalid and excessive updates. There is one latest location per session, not a location history. Map rendering never creates GPS fixes. Position updates older than the previous fix are dropped; accuracy is not cosmetically improved. Distance threshold is 5 m; uploads are at most once per 5 seconds. Tracking stops on backgrounding or leaving the relevant screen. Resume currently requires explicitly enabling tracking again.

## Routing

The outdoor verified `campusPaths/walking` graph uses x=latitude, y=longitude. Distances are surveyed meters, not pixel distances. A user confirms a graph checkpoint and selects a destination whose node ID or label matches the building ID. Indoor graph nodes use normalized plan coordinates plus floor IDs. Directional edges express elevators/stairs/floor transitions. Missing/disconnected graphs return no route. Dijkstra is O(V² + VE) in this small-campus implementation; replace with a priority queue for large surveys.

## Demo isolation

The illustration uses normalized fictional coordinates. Demo locations have no latitude/longitude and are unverified. The demo QR namespace is `srm-demo`, separate from `srm-campus`. Demo friend state is memory-only. No demo location is uploaded to Firebase. Distances and floor layouts are fictional and visibly labelled.

## Limitations

Advanced BLE/Wi-Fi RTT/barometer positioning is not implemented. No background service or background location permission exists. Production boundary and building-polygon UI integration remains pending (the uncertainty classifier is implemented and tested). Plan overlays and sophisticated graphical survey authoring remain extensions. Admin structured-record editing is available. Do not deploy to students before the two-device acceptance checklist passes.
