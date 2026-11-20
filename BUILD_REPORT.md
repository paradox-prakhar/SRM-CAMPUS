# SRM AP Smart Campus Navigator — Build & Verification Report

**Date & Time**: 2026-11-19 00:46 IST  
**Target Platform**: Android (First-Class), Web (Presentation Mode)  
**Package Name**: `edu.srmap.campus_navigator`  
**Flutter SDK**: 3.44.1 • Channel stable  
**Dart SDK**: 3.12.1  
**Java & Gradle**: OpenJDK 17+, Gradle 9.3.1  
**Android Compile / Target SDK**: 34 (Android 14)  

---

## 1. Automated Test Suite Results

Command: `flutter test`
Outcome: **10 passed, 0 failed, 0 skipped** (100% pass rate)

| Test File | Test Case | Status |
|---|---|---|
| `test/domain_test.dart` | Dijkstra chooses shortest route and returns real graph edges | PASSED |
| `test/domain_test.dart` | Accessible routing avoids stairs, disconnected nodes have no route | PASSED |
| `test/domain_test.dart` | Floor QR rejects wrong namespace, arbitrary URLs and unknown IDs | PASSED |
| `test/domain_test.dart` | Confirmation expires at exact TTL and rejects backwards time | PASSED |
| `test/domain_test.dart` | Floor coordinate transformation round trips | PASSED |
| `test/domain_test.dart` | Boundary distinguishes inside, outside, uncertain and missing | PASSED |
| `test/domain_test.dart` | Unverified places never become map markers | PASSED |
| `test/indoor_social_test.dart` | Manual floor and QR-confirmed floor have distinct sources | PASSED |
| `test/indoor_social_test.dart` | Sharing starts only after consent and stop removes demo marker | PASSED |
| `test/widget_test.dart` | Onboarding opens isolated simulation and indoor QR | PASSED |

---

## 2. Static Analysis

Command: `flutter analyze`  
Outcome: **No issues found!** (Clean build, 0 errors, 0 warnings, 0 linter hints)

---

## 3. Android APK Binary Details

Command: `flutter build apk --debug`  
Status: **SUCCESS**  
Output Path: `build/app/outputs/flutter-apk/app-debug.apk`  
File Size: **193,190,982 bytes (~184 MB)**  
Build Duration: 545.1 seconds (includes Android SDK Platform 34 installation and Gradle dependency resolution)

### Installation Command
To install onto any connected physical Android device or emulator:
```powershell
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

---

## 4. Feature Implementation & Verification Summary

1. **Interactive Campus Map & Navigation**:
   - Google Maps SDK for Android with dynamic layer switching (Normal, Satellite, Hybrid).
   - Real GPS device tracking via Geolocator Fused Location Provider with accuracy indicator and low-accuracy warning (`> 40m`).
   - Compass widget and follow-user camera tracking.
   - Surveyed campus path graph routing via Dijkstra algorithm with step-by-step turn guidance.
   - Real-time simulation walking player with `1x`, `2x`, `4x` speed controls.

2. **Indoor Multi-Floor Navigation & QR Checkpoints**:
   - Multi-floor level selector (Ground, Floor 1).
   - Interactive vector floor plan with color-coded room zones, entrance indicators, and glowing path routing.
   - Level A: Explicit manual selection.
   - Level B: Cryptographic QR checkpoint verification (`srm-campus://checkpoint/{id}` or `srm-demo://checkpoint/{id}`) with real-time countdown timer to 10-minute TTL expiry.
   - Level C: Sensor-assisted status indicator documenting barometer calibration requirements.
   - Built-in camera scanner (`mobile_scanner`) and presentation QR generator (`qr_flutter`).

3. **Opt-in Live Location Sharing**:
   - Explicit session initiation with durations: 15 min, 30 min, 1 hour, or until stopped (capped at 24 hours).
   - Active countdown timer and live viewer list.
   - One-tap immediate `Stop Sharing` emergency revocation.
   - Separate Friend Management system (friendship never implies location sharing permission).
   - Foreground-only location streaming; stops tracking when app is paused/backgrounded.

4. **SRM AP Official 360° Virtual Campus Tour**:
   - Deep-linked integration to `https://www.srmap.edu.in/life-at-srmap/virtual-campus-tour/`.

5. **Authenticated Admin Campus Data Management**:
   - Role-based access control checking `admin` custom claims.
   - Surveyed building, entrance, floor, room, and path JSON schema editor with validation.
