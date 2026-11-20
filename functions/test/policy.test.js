const {test}=require('node:test');
const assert=require('node:assert/strict');
const {duration,validPosition,canView}=require('../policy');
test('sharing duration accepts only supported values',()=>{assert.equal(duration(15),900000);assert.equal(duration(0),86400000);assert.throws(()=>duration(-1));});
test('only owner or accepted viewer may read before expiration',()=>{
 const s={ownerId:'a',viewerIds:['b'],status:'active',expiresAt:100};
 assert.equal(canView(s,'b',99),true);assert.equal(canView(s,'c',99),false);assert.equal(canView(s,'b',100),false);
 assert.equal(canView({...s,status:'stopped'},'b',1),false);assert.equal(canView({...s,status:'pending'},'b',1),false);
});
test('reject stale, future, nonfinite and out-of-range GPS',()=>{
 const p={latitude:16,longitude:80,accuracyMeters:12,recordedAt:100000};
 assert.equal(validPosition(p,100001),true);
 for(const change of [{latitude:91},{longitude:181},{accuracyMeters:-1},{latitude:NaN},{recordedAt:1},{recordedAt:110000}]) assert.equal(validPosition({...p,...change},100000),false);
});
