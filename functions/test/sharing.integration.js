const {test}=require('node:test');
const assert=require('node:assert/strict');
const {initializeApp,deleteApp}=require('firebase/app');
const {getAuth,connectAuthEmulator,createUserWithEmailAndPassword}=require('firebase/auth');
const {getFunctions,connectFunctionsEmulator,httpsCallable}=require('firebase/functions');
const {getFirestore,connectFirestoreEmulator,doc,getDoc}=require('firebase/firestore');
async function account(label) {
  const app=initializeApp({projectId:'demo-campus',apiKey:'fake-api-key',appId:'1:123:android:test'},label);
  const auth=getAuth(app);connectAuthEmulator(auth,'http://127.0.0.1:9099',{disableWarnings:true});
  const functions=getFunctions(app);connectFunctionsEmulator(functions,'127.0.0.1',5001);
  const db=getFirestore(app);connectFirestoreEmulator(db,'127.0.0.1',8080);
  const user=(await createUserWithEmailAndPassword(auth,`${label}-${Date.now()}@example.test`,'Test-pass-12345!')).user;
  return {app,uid:user.uid,db,call:async(name,data)=>(await httpsCallable(functions,name)(data)).data};
}
test('two-account sharing requires invitation acceptance and revokes immediately',async()=>{
  const a=await account('owner'),b=await account('viewer'),c=await account('stranger');
  try {
    await assert.rejects(()=>a.call('createShare',{viewerId:b.uid,minutes:15}));
    await a.call('friendAction',{action:'request',targetId:b.uid});
    await b.call('friendAction',{action:'accept',requestId:`${a.uid}_${b.uid}`});
    const share=await a.call('createShare',{viewerId:b.uid,minutes:15});
    await a.call('publishLocation',{sessionId:share.sessionId,latitude:16,longitude:80,accuracyMeters:15,recordedAt:Date.now()});
    await assert.rejects(()=>getDoc(doc(b.db,'locationUpdates',share.sessionId)));
    await assert.rejects(()=>c.call('acceptShare',{invitationId:share.invitationId}));
    await b.call('acceptShare',{invitationId:share.invitationId});
    assert.equal((await getDoc(doc(b.db,'locationUpdates',share.sessionId))).data().latitude,16);
    await assert.rejects(()=>getDoc(doc(c.db,'locationUpdates',share.sessionId)));
    await a.call('stopShare',{sessionId:share.sessionId});
    await assert.rejects(()=>getDoc(doc(b.db,'locationUpdates',share.sessionId)));
    await assert.rejects(()=>a.call('publishLocation',{sessionId:share.sessionId,latitude:16,longitude:80,accuracyMeters:15,recordedAt:Date.now()}));
  } finally {await Promise.all([a,b,c].map(u=>deleteApp(u.app)));}
});
