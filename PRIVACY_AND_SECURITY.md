# Privacy and security

Sharing is off by default. An authenticated owner selects one accepted friend and a duration. A random invitation ID is bound server-side to that specific viewer; knowledge of the ID is not sufficient. Acceptance is single-use. A friendship alone never grants location access.

Cloud Functions validates both identities, friendship, block state and expiry in transactions. Clients cannot write session ACLs or location updates. Firestore rules require active status, unexpired server time, existing friendship, no blocks and an owner/authorized viewer identity. Admin map privileges do not grant location reads. The owner can end a session or all sessions; the live fix and viewer discovery pointer are deleted. Removing/blocking friends revokes associated shares. Expiry is checked in rules even if cleanup is delayed.

The app does not request background location. Leaving the sharing screen cancels its device stream. Session access may remain active until stopped/expired, displaying a clearly stale last fix; no further positions are published from that screen. On sign-out the client first calls server revocation; failure is surfaced. Deletion requires a recent sign-in and removes user data and relationships before deleting the Auth account.

## Deployment requirements

- Use Firebase's configured Android app identity and an API-restricted Google Maps key restricted to package + signing SHA-1.
- Never include service-account JSON in the repository or app bundle. Public Firebase client options are not authorization secrets; rules and authenticated server code enforce access.
- Assign admin custom claims only through a trusted Admin SDK operator. A client profile field cannot assign a role.
- Enable App Check enforcement for callable Functions before a public rollout and add per-account request quotas / abuse monitoring. This initial implementation limits location write frequency; friend/invite abuse limits require further hardening.
- Confirm applicable institutional privacy policy and retention requirements before collecting student locations.
- For release, configure your own Android signing key. The provided build uses debug signing for development only.

## QR limitations

A checkpoint QR identifies a known floor at scan time. It is copyable and is neither continuous positioning nor secure proof of physical presence. Manual and QR sources are separately labelled; confirmation expires after 10 minutes. No uncalibrated altitude is called a floor.

## Remaining security validation

Run emulator tests after every rules change. Run two-account/device testing before deployment, including airplane mode, app backgrounding, revocation while a listener is open, server expiry, blocking and account deletion. App Check and production abuse monitoring are deployment work, not silently assumed complete.
