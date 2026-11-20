# Firestore schema

Server-managed collections cannot be written directly by clients. All timestamps are Firestore Timestamp values, not strings, unless explicitly indicated.

| Collection | Document fields / access |
|---|---|
| users/{uid} | displayName, createdAt; only owner reads; Firebase Auth retains private email |
| userPreferences/{uid} | dark:boolean, units:metric/imperial, notifications:boolean; owner only |
| friendRequests/{from_to} | from, to, status:pending/accepted/rejected, createdAt; participants read |
| friendships/{sortedUIDs} | members:[uid,uid], createdAt; pair IDs use colon separator; participants read |
| users/{uid}/blocks/{other} | createdAt; server writes, owner reads |
| buildings/{id} | name, category, description, latitude?, longitude?, verified, published, facilities:[], updatedBy, updatedAt |
| buildingEntrances/{id} | buildingId, name, latitude, longitude, nodeId, accessible, verified |
| floors/{id} | buildingId, label, planUrl (authorized HTTPS image), verified |
| floorPlans/{id} | buildingId, floorId, imageUrl, width, height, authorizationSource, verified |
| rooms/{id} | buildingId, floorId, name, nodeId, x, y, verified |
| campusPaths/walking | verified, nodes:[], edges:[] |
| indoorPaths/{buildingId} | verified, nodes:[], edges:[] |
| qrCheckpoints/{id} | buildingId, floorId, verified; QR text is srm-campus://checkpoint/{id} |
| campusBoundaries/{id} | vertices:[{latitude,longitude}], source, verified; production UI pending |
| locationShareSessions/{id} | ownerId, invitedViewerId, friendshipId, viewerIds:[], status, expiresAt, createdAt, stoppedAt? |
| locationShareInvitations/{id} | ownerId, viewerId, sessionId, status, expiresAt |
| locationUpdates/{sessionId} | ownerId, latitude, longitude, accuracyMeters, recordedAt, receivedAt, expiresAt; latest only |
| users/{viewer}/receivedShares/{sessionId} | ownerId, expiresAt; private discovery pointer, not a location |

## Graph format

This is a schema example, **not campus geography**. Do not publish example coordinates as surveyed.

```json
{
  "verified": false,
  "nodes": [
    {"id":"entrance", "label":"Entrance", "floor":"ground", "x":0.1, "y":0.5},
    {"id":"lift_g", "label":"Ground elevator", "floor":"ground", "x":0.8, "y":0.5},
    {"id":"lift_1", "label":"First elevator", "floor":"first", "x":0.8, "y":0.5}
  ],
  "edges": [
    {"from":"entrance", "to":"lift_g", "meters":20, "accessible":true, "instruction":"Follow the corridor to the elevator"},
    {"from":"lift_g", "to":"lift_1", "meters":4, "accessible":true, "instruction":"Take the elevator to the first floor"}
  ]
}
```

Add reverse edges explicitly for bidirectional paths. Outdoor x/y are latitude/longitude, indoor x/y are normalized [0,1] plan coordinates. Use survey-measured distances and authorized plans. Floor count is derived only from verified floor records; no real campus floor count is preloaded.

## Indexes and retention

Deploy `firestore.indexes.json`. Hourly cleanup removes expired location/session/invitation records in bounded batches; access expires immediately in rules regardless of cleanup delay. Configure Firestore TTL on expiresAt for locationUpdates, locationShareSessions, locationShareInvitations and collection group receivedShares as a second cleanup mechanism. Location privacy does not depend on TTL timing.
