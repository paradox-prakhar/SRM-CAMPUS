# Viva preparation

**Why Flutter?** One reusable Dart UI and domain layer with Android-native location/maps plugins. Riverpod separates state, go_router separates navigation, repositories separate external services.

**How does routing work?** Dijkstra traverses a directed surveyed graph. Edge weight is measured distance; inaccessible edges can be excluded. No graph or disconnected nodes means no invented route.

**Can GPS determine floors?** Not reliably. Manual selection and validated QR checkpoints are implemented. A QR scan expires and does not prove continuous presence. Barometer/BLE/Wi-Fi RTT need calibrated hardware and are not implemented.

**How is location private?** Sharing is explicit, invitations are bound to authenticated viewers, friendship is separate, and Firestore rules deny reads after expiry/revocation. Administrators only manage campus data.

**What reduces battery use?** Foreground streams, 5 m distance filter, 5-second upload throttling, cleanup on navigation/backgrounding, and no continuous history. Adaptive motion-based polling is an extension.

**What does the demo prove?** Interface interactions, graph routing, manual floor switching, QR validation, simulated sharing controls. It does not prove real GPS accuracy, campus survey correctness, or two-device Firebase behavior.

**What must happen before launch?** Configure Firebase and restricted Maps API key; load verified surveys/authorized plans; deploy rules/functions; configure release signing and App Check; perform physical-device/two-account acceptance tests.
