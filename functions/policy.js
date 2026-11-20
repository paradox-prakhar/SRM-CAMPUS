'use strict';
function duration(minutes) {
  if (![0, 15, 30, 60].includes(minutes)) throw new Error('Invalid duration');
  return (minutes === 0 ? 1440 : minutes) * 60000;
}
function validPosition(p, now) {
  return Number.isFinite(p.latitude) && Math.abs(p.latitude) <= 90
    && Number.isFinite(p.longitude) && Math.abs(p.longitude) <= 180
    && Number.isFinite(p.accuracyMeters) && p.accuracyMeters >= 0 && p.accuracyMeters <= 10000
    && Number.isFinite(p.recordedAt) && now - p.recordedAt <= 30000 && p.recordedAt <= now + 5000;
}
function canView(session, uid, now) {
  return session.status === 'active' && session.expiresAt > now
    && (session.ownerId === uid || session.viewerIds.includes(uid));
}
module.exports = {duration, validPosition, canView};
