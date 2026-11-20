const {test,before,after,beforeEach}=require('node:test');
const fs=require('node:fs');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,Timestamp}=require('firebase/firestore');
let env;
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-campus',firestore:{rules:fs.readFileSync('../firestore.rules','utf8'),host:'127.0.0.1',port:8080}});});
after(async()=>env?.cleanup());
beforeEach(async()=>{await env.clearFirestore();await env.withSecurityRulesDisabled(async c=>{
 const db=c.firestore();
 await setDoc(doc(db,'locationShareSessions/s1'),{ownerId:'owner',invitedViewerId:'viewer',friendshipId:'owner:viewer',viewerIds:['viewer'],status:'active',expiresAt:Timestamp.fromMillis(Date.now()+60000)});
 await setDoc(doc(db,'locationUpdates/s1'),{latitude:16,longitude:80});
 await setDoc(doc(db,'friendships/owner:viewer'),{members:['owner','viewer']});
});});
test('owner and authorized viewer can read, unrelated student and admin cannot',async()=>{
 for(const uid of ['owner','viewer']) await assertSucceeds(getDoc(doc(env.authenticatedContext(uid).firestore(),'locationUpdates/s1')));
 await assertFails(getDoc(doc(env.authenticatedContext('stranger').firestore(),'locationUpdates/s1')));
 await assertFails(getDoc(doc(env.authenticatedContext('admin',{admin:true}).firestore(),'locationUpdates/s1')));
 await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'locationUpdates/s1')));
});
test('clients cannot forge sharing authorization or location updates',async()=>{
 await assertFails(setDoc(doc(env.authenticatedContext('owner').firestore(),'locationUpdates/s1'),{latitude:1}));
 await assertFails(setDoc(doc(env.authenticatedContext('viewer').firestore(),'locationShareSessions/s1'),{viewerIds:['stranger']},{merge:true}));
});
test('expiry and revocation deny reads',async()=>{
 await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'locationShareSessions/s1'),{expiresAt:Timestamp.fromMillis(Date.now()-1000)},{merge:true}));
 await assertFails(getDoc(doc(env.authenticatedContext('viewer').firestore(),'locationUpdates/s1')));
 await env.withSecurityRulesDisabled(c=>setDoc(doc(c.firestore(),'locationShareSessions/s1'),{status:'stopped',expiresAt:Timestamp.fromMillis(Date.now()+60000)},{merge:true}));
 await assertFails(getDoc(doc(env.authenticatedContext('viewer').firestore(),'locationUpdates/s1')));
});
test('students cannot publish campus geometry or assign themselves admin',async()=>{
 const db=env.authenticatedContext('student').firestore();
 await assertFails(setDoc(doc(db,'buildings/library'),{name:'Library',verified:true,published:true,latitude:16,longitude:80}));
 await assertFails(setDoc(doc(db,'users/student'),{displayName:'Student',admin:true}));
});
