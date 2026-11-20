'use strict';
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {initializeApp} = require('firebase-admin/app');
const {getFirestore, Timestamp, FieldValue} = require('firebase-admin/firestore');
const {getAuth} = require('firebase-admin/auth');
const {duration, validPosition} = require('./policy');
initializeApp();
const db = getFirestore();
const fail = (message) => { throw new HttpsError('permission-denied', message); };
const uidOf = (r) => r.auth?.uid || fail('Sign in first.');
const pairId = (a, b) => [a, b].sort().join(':');
const identifier = (s) => typeof s === 'string' && /^[a-zA-Z0-9_-]{1,128}$/.test(s);
const callable = (fn) => onCall({maxInstances: 10}, fn);
async function friendship(tx, a, b) {
  const refs = [db.doc(`friendships/${pairId(a,b)}`), db.doc(`users/${a}/blocks/${b}`), db.doc(`users/${b}/blocks/${a}`)];
  const [friends, blockedA, blockedB] = await Promise.all(refs.map(r => tx.get(r)));
  if(!friends.exists || blockedA.exists || blockedB.exists) fail('An unblocked accepted friendship is required.');
}
async function revokeQuery(query) {
  const docs = await query.get();
  for(const doc of docs.docs) {
    await db.runTransaction(async tx => {
      const fresh = await tx.get(doc.ref); if(!fresh.exists) return;
      const s = fresh.data();
      tx.update(doc.ref, {status: 'stopped', viewerIds: [], stoppedAt: FieldValue.serverTimestamp()});
      tx.delete(db.doc(`locationUpdates/${doc.id}`));
      for(const viewer of s.viewerIds || []) tx.delete(db.doc(`users/${viewer}/receivedShares/${doc.id}`));
    });
  }
}
exports.friendAction = callable(async r => {
  const uid = uidOf(r), {action, targetId, requestId} = r.data;
  if(['accept','reject'].includes(action)) {
    if(!identifier(requestId)) fail('Invalid request.');
    await db.runTransaction(async tx => {
      const request = db.doc(`friendRequests/${requestId}`), snap = await tx.get(request), data = snap.data();
      if(!data || data.to !== uid || data.status !== 'pending') fail('Request not available.');
      const blocked = await Promise.all([tx.get(db.doc(`users/${uid}/blocks/${data.from}`)), tx.get(db.doc(`users/${data.from}/blocks/${uid}`))]);
      if(blocked.some(d => d.exists)) fail('Blocked.');
      tx.update(request, {status: action === 'accept' ? 'accepted' : 'rejected'});
      if(action === 'accept') tx.set(db.doc(`friendships/${pairId(uid,data.from)}`), {members: [uid,data.from], createdAt: FieldValue.serverTimestamp()});
    });
  } else {
    if(!identifier(targetId) || targetId === uid) fail('Invalid user ID.');
    if(action === 'request') {
      await getAuth().getUser(targetId).catch(() => fail('Account unavailable.'));
      await db.runTransaction(async tx => {
        const [a,b] = await Promise.all([tx.get(db.doc(`users/${uid}/blocks/${targetId}`)),tx.get(db.doc(`users/${targetId}/blocks/${uid}`))]);
        if(a.exists || b.exists) fail('Account unavailable.');
        tx.set(db.doc(`friendRequests/${uid}_${targetId}`), {from: uid, to: targetId, status: 'pending', createdAt: FieldValue.serverTimestamp()});
      });
    } else if(['remove','block'].includes(action)) {
      await db.runTransaction(async tx => {
        tx.delete(db.doc(`friendships/${pairId(uid,targetId)}`));
        if(action === 'block') tx.set(db.doc(`users/${uid}/blocks/${targetId}`), {createdAt: FieldValue.serverTimestamp()});
      });
      // Revoke both directions; pending invitations also cannot be accepted without friendship.
      await revokeQuery(db.collection('locationShareSessions').where('ownerId','==',uid).where('invitedViewerId','==',targetId));
      await revokeQuery(db.collection('locationShareSessions').where('ownerId','==',targetId).where('invitedViewerId','==',uid));
    } else fail('Unknown action.');
  }
  return {ok:true};
});
exports.createShare = callable(async r => {
  const uid = uidOf(r), {viewerId, minutes} = r.data;
  if(!identifier(viewerId) || viewerId === uid) fail('Invalid viewer.');
  let millis; try { millis = duration(minutes); } catch { fail('Invalid duration.'); }
  const session = db.collection('locationShareSessions').doc(), invitation = db.collection('locationShareInvitations').doc();
  const expiresAt = Timestamp.fromMillis(Date.now() + millis);
  await db.runTransaction(async tx => {
    await friendship(tx,uid,viewerId);
    tx.create(session, {ownerId:uid, invitedViewerId:viewerId, friendshipId:pairId(uid,viewerId), viewerIds:[], status:'pending', expiresAt, createdAt:FieldValue.serverTimestamp()});
    tx.create(invitation,{ownerId:uid,viewerId,sessionId:session.id,status:'pending',expiresAt:Timestamp.fromMillis(Math.min(expiresAt.toMillis(),Date.now()+15*60000))});
  });
  return {sessionId:session.id, invitationId:invitation.id, expiresAt:expiresAt.toMillis()};
});
exports.acceptShare = callable(async r => {
  const uid = uidOf(r), {invitationId} = r.data;
  if(!identifier(invitationId)) fail('Invalid invitation.');
  await db.runTransaction(async tx => {
    const invitation = db.doc(`locationShareInvitations/${invitationId}`), snap = await tx.get(invitation), i = snap.data();
    if(!i || i.viewerId !== uid || i.status !== 'pending' || i.expiresAt.toMillis() <= Date.now()) fail('Invitation unavailable.');
    const session = db.doc(`locationShareSessions/${i.sessionId}`), s = (await tx.get(session)).data();
    if(!s || s.status !== 'pending' || s.expiresAt.toMillis() <= Date.now()) fail('Session unavailable.');
    await friendship(tx,s.ownerId,uid);
    tx.update(session,{status:'active',viewerIds:[uid]}); tx.update(invitation,{status:'accepted'});
    tx.set(db.doc(`users/${uid}/receivedShares/${i.sessionId}`),{ownerId:s.ownerId,expiresAt:s.expiresAt});
  });
  return {ok:true};
});
exports.publishLocation = callable(async r => {
  const uid = uidOf(r), p = r.data;
  if(!identifier(p.sessionId) || !validPosition(p,Date.now())) fail('Invalid or stale position.');
  await db.runTransaction(async tx => {
    const s = (await tx.get(db.doc(`locationShareSessions/${p.sessionId}`))).data();
    if(!s || s.ownerId !== uid || s.expiresAt.toMillis() <= Date.now() || !['pending','active'].includes(s.status)) fail('Session unavailable.');
    await friendship(tx,uid,s.invitedViewerId);
    const ref = db.doc(`locationUpdates/${p.sessionId}`), old = (await tx.get(ref)).data();
    if(old && (old.recordedAt.toMillis() >= p.recordedAt || Date.now()-old.receivedAt.toMillis()<4000)) fail('Out-of-order or excessive updates.');
    tx.set(ref,{ownerId:uid,latitude:p.latitude,longitude:p.longitude,accuracyMeters:p.accuracyMeters,recordedAt:Timestamp.fromMillis(p.recordedAt),receivedAt:FieldValue.serverTimestamp(),expiresAt:s.expiresAt});
  });
  return {ok:true};
});
exports.stopShare = callable(async r => {
  const uid = uidOf(r), {sessionId} = r.data;
  if(!identifier(sessionId)) fail('Invalid session.');
  await db.runTransaction(async tx => {
    const ref = db.doc(`locationShareSessions/${sessionId}`), s = (await tx.get(ref)).data();
    if(!s || s.ownerId !== uid) fail('Not your session.');
    tx.update(ref,{status:'stopped',viewerIds:[],stoppedAt:FieldValue.serverTimestamp()}); tx.delete(db.doc(`locationUpdates/${sessionId}`));
    for(const viewer of s.viewerIds) tx.delete(db.doc(`users/${viewer}/receivedShares/${sessionId}`));
  });
  return {ok:true};
});
exports.stopAllSharing = callable(async r => { const uid=uidOf(r); await revokeQuery(db.collection('locationShareSessions').where('ownerId','==',uid)); return {ok:true}; });
exports.deleteAccount = callable(async r => {
  const uid=uidOf(r);
  if(Date.now()/1000-r.auth.token.auth_time > 300) throw new HttpsError('failed-precondition','Sign in again before deleting your account.');
  await revokeQuery(db.collection('locationShareSessions').where('ownerId','==',uid));
  await revokeQuery(db.collection('locationShareSessions').where('invitedViewerId','==',uid));
  for(const [collection,field,operator] of [['friendRequests','from','=='],['friendRequests','to','=='],['friendships','members','array-contains'],['locationShareInvitations','ownerId','=='],['locationShareInvitations','viewerId','=='],['locationShareSessions','ownerId','=='],['locationShareSessions','invitedViewerId','==']]) {
    const docs=await db.collection(collection).where(field,operator,uid).get();
    for(const doc of docs.docs) await doc.ref.delete();
  }
  await db.recursiveDelete(db.doc(`users/${uid}`)); await db.doc(`userPreferences/${uid}`).delete();
  await getAuth().deleteUser(uid); return {ok:true};
});
exports.cleanupExpiredShares = onSchedule('every 60 minutes', async () => {
  const now=Timestamp.now();
  for(const collection of ['locationUpdates','locationShareInvitations','locationShareSessions']) {
    const docs=await db.collection(collection).where('expiresAt','<=',now).limit(400).get();
    const batch=db.batch(); for(const doc of docs.docs) batch.delete(doc.ref); await batch.commit();
  }
});
