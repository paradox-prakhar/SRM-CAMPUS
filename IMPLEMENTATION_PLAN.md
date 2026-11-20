# SRM AP Smart Campus Navigator — Master Implementation Plan

## Project Overview
A production-grade, Android-first Flutter application engineered exclusively for SRM University AP (Neerukonda, Andhra Pradesh, India). Provides real-time interactive campus mapping, surveyed outdoor routing, multi-floor indoor floor plans with QR checkpoint validation, secure opt-in friend location sharing, official 360° virtual tour integration, and authenticated campus geometry administration.

---

## Architecture & System Design
The project adheres to clean architecture with strict layer separation:
1. **Domain Layer (`lib/domain/`)**:
   - Pure Dart models: `CampusPlace`, `RouteNode`, `RouteEdge`, `CampusRoute`, `RoutingGraph` (Dijkstra algorithm), `FloorConfirmation`, `Checkpoint`, `FloorTransform`.
   - Geospatial logic: Local tangent plane projection, ray-casting point-in-polygon campus boundary detection with accuracy buffer.
2. **Data Layer (`lib/data/`)**:
   - `services.dart`: `AppConfig`, `CampusRepository`, `DeviceLocation` (Fused Location Provider with adaptive filtering, stale checks, accuracy filtering).
   - `geospatial.dart`: `GeoVertex`, geodesic-to-planar projection and boundary classification.
3. **Application State Layer (`lib/application/`)**:
   - Riverpod state management (`app_state.dart`): `appProvider`, `demoSearchProvider`, theme configuration (light/dark mode, SRM university palette).
4. **Presentation Layer (`lib/presentation/`)**:
   - `explorer.dart`: Interactive campus map, animated simulation with turn-by-turn navigation, search, building cards, layer switching, follow mode.
   - `components.dart`: Reusable UI components, status pills, category icons, interactive vector floor painters, compass, radar animations.
   - `screens.dart`: Welcome onboarding, Authentication, Indoor floor viewer with room routing & QR verification, Admin campus data editor, Settings.
   - `social.dart`: Opt-in live location sharing, friend management, session timers, access revocation.

---

## Implementation Roadmap & Checkpoints

### Phase 1: Foundation & SRM University Identity
- [x] Flutter SDK 3.44+ & Dart 3.12+ project setup with sound null-safety.
- [x] Riverpod state management & GoRouter navigation.
- [x] SRM AP visual theme: SRM Navy Blue (`#1A365D`), Forest Emerald (`#0F5132`), Amber Accent (`#D97706`), Light/Dark mode.
- [x] Onboarding & Splash experience with clear privacy explanations.
- [x] Configurable Firebase Authentication (Email/Password, password reset, session persistence).

### Phase 2: Interactive Campus Map & Location Engine
- [x] Google Maps SDK integration for Android (`google_maps_flutter`).
- [x] Android runtime permission workflow (`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`).
- [x] Real-time device location tracking via Geolocator Fused Location Provider.
- [x] Low-accuracy warning (`> 40m`), stale location detection (`> 30s`), accuracy radius circle.
- [x] Follow mode vs. free map exploration toggle.
- [x] Normal, Satellite, and Hybrid map view switcher.
- [x] Campus boundary classification (Inside, Outside, Uncertain, Unavailable).
- [x] Interactive building identification with proximity check and manual user confirmation.

### Phase 3: Surveyed Campus Navigation Graph
- [x] Campus walking graph data model with nodes, edges, distance in meters, and accessibility flags.
- [x] Dijkstra shortest path routing algorithm with step-by-step instructions.
- [x] Accessible routing mode avoiding staircases.
- [x] Interactive turn-by-turn guidance card with ETA, distance, and animated progress.
- [x] Interactive walking simulation mode with variable speed controls (1x, 2x, 4x) for presentations.

### Phase 4: Indoor Multi-Floor Navigation & QR Checkpoints
- [x] Multi-floor selector (Ground, Floor 1, Floor 2, Floor 3).
- [x] Interactive vector floor plan canvas (`FloorPainter`):
  - Clickable rooms with visual selection highlights.
  - Corridors, staircases, elevators, and entrances.
  - Animated indoor path highlighting from entrance/checkpoint to destination room.
- [x] Multi-level floor identification:
  - **Level A**: Explicit manual floor selection.
  - **Level B**: Cryptographic QR checkpoint confirmation (`srm-campus://checkpoint/{id}`) with 10-minute TTL expiry.
  - **Level C**: Sensor-assisted estimation status indicator (calibrated barometer/step counter limitations clearly stated).
  - **Level D**: Extensible BLE/Wi-Fi RTT adapter specification.
- [x] In-app camera scanner (`mobile_scanner`) and presentation QR checkpoint generator (`qr_flutter`).

### Phase 5: Secure Live Location Sharing & Friends
- [x] Explicit opt-in sharing session lifecycle (15 min, 30 min, 1 hour, until stopped).
- [x] One-tap immediate "Stop Sharing" button revoking all active viewer permissions.
- [x] Live remaining time countdown with animated circular progress indicator.
- [x] Friend system: Search by email/UID, send/accept/reject/remove friend requests.
- [x] Strict security boundary: Friendship does NOT grant location access; requires explicit session invitation.
- [x] Background tracking protection: Foreground tracking only; streams pause when app leaves foreground.

### Phase 6: Official Virtual Tour & Building Explorer
- [x] Deep link integration with SRM University AP official virtual campus tour (`https://www.srmap.edu.in/life-at-srmap/virtual-campus-tour/`).
- [x] Rich building details bottom sheet: photos, description, verified facilities tags, floor counts, operating hours.
- [x] Category search & filter: Study, Academic, Food, Sports, Living, Administrative, Facilities.

### Phase 7: Authenticated Admin Portal & Data Governance
- [x] Role-based admin access control (`admin` custom token claim).
- [x] Surveyed building record creator (ID, name, category, verified coordinates, description, facilities).
- [x] JSON schema editor for verified campus paths, indoor graphs, entrances, floors, and QR checkpoints.
- [x] Draft vs. Verified vs. Published state management to protect map integrity.

### Phase 8: Quality Assurance, Verification & Delivery
- [x] Unit tests for routing graph (Dijkstra shortest path, accessibility filtering, disconnected graphs).
- [x] Unit tests for QR checkpoint validation, namespace integrity, and TTL expiry.
- [x] Unit tests for geospatial boundary classification.
- [x] Widget tests for navigation and UI flow.
- [x] All automated tests passing (`flutter test`).
- [x] Comprehensive documentation: `README.md`, `ARCHITECTURE.md`, `DATABASE_SCHEMA.md`, `PRIVACY_AND_SECURITY.md`, `CAMPUS_DATA_SETUP.md`, `DEMO_GUIDE.md`, `VIVA_PREPARATION.md`.
