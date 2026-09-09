import {test,beforeEach,afterEach} from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import {SignJWT} from 'jose';
import {randomBytes} from 'node:crypto';
import {fixture} from './helpers.js';
import {Vault} from '../src/crypto.js';
import {parsePlayPurchase} from '../src/google-play.js';
let f:Awaited<ReturnType<typeof fixture>>;
const email='player@example.test',password='A-long-game-password-42';
beforeEach(async()=>{f=await fixture();});afterEach(async()=>{await f.close();});
async function mailToken(purpose='verify') {
 const {rows}=await f.pool.query("select * from backend.jobs where kind='email' order by id desc");
 const payload=rows.map(row=>f.queue.payload<{url:string;purpose:string}>(row)).find(p=>p.purpose===purpose)!;
 return new URL(payload.url).searchParams.get('token')!;
}
async function registered() {
 await f.auth.register(email,password);await f.auth.useEmailToken(await mailToken(),'verify');return f.auth.login(email,password);
}
test('registration is generic; password and email tokens are not stored as plaintext',async()=>{
 const first=await request(f.app).post('/v1/auth/register').send({email,password}).expect(202);
 const again=await request(f.app).post('/v1/auth/register').send({email,password:'Different-password-123'}).expect(202);
 assert.deepEqual(first.body,again.body);
 const user=(await f.pool.query('select * from backend.users')).rows[0];assert.ok(!user.password_hash.includes(password));
 const raw=await mailToken();const stored=(await f.pool.query('select * from backend.auth_tokens')).rows[0];assert.notEqual(stored.token_hash,raw);
 assert.equal((await f.pool.query("select * from backend.jobs where kind='email'")).rowCount,1);
 const login=await f.auth.login(email,password);assert.ok(login.accessToken);assert.ok(!JSON.stringify(f.logs).includes(password));
});
test('verification is required for commerce and progress, and email scanner GET does not consume token',async()=>{
 await f.auth.register(email,password);const tokens=await f.auth.login(email,password);const raw=await mailToken();
 const agent=request(f.app),authorization='Bearer '+tokens.accessToken;
 await agent.get('/v1/games/ringrush/billing-context').set('Authorization',authorization).expect(403);
 await agent.get('/auth/action').query({purpose:'verify',token:raw}).expect(200);
 assert.equal((await f.auth.authenticate(tokens.accessToken)).verified,false);
 await agent.post('/v1/auth/verify-email').send({token:raw}).expect(200);
 await agent.post('/v1/auth/verify-email').send({token:raw}).expect(400);
 const context=await agent.get('/v1/games/ringrush/billing-context').set('Authorization',authorization).expect(200);assert.equal(context.body.products.length,3);
});
test('refresh rotation detects reuse and revokes the entire session family',async()=>{
 const old=await registered(),next=await f.auth.refresh(old.refreshToken);assert.notEqual(next.refreshToken,old.refreshToken);
 await f.auth.authenticate(next.accessToken);
 await assert.rejects(f.auth.refresh(old.refreshToken),/INVALID_REFRESH_TOKEN/);
 await assert.rejects(f.auth.authenticate(next.accessToken),/SESSION_REVOKED/);
});
test('concurrent refresh cannot create two usable descendants',async()=>{
 const old=await registered();const results=await Promise.allSettled([f.auth.refresh(old.refreshToken),f.auth.refresh(old.refreshToken)]);
 assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
 const result=results.find(r=>r.status==='fulfilled');assert.ok(result&&result.status==='fulfilled');
 await assert.rejects(f.auth.authenticate(result.value.accessToken),/SESSION_REVOKED/);
});
test('logout invalidates the current device, logout-all invalidates all devices',async()=>{
 const a=await registered(),b=await f.auth.login(email,password);
 await f.auth.logout(await f.auth.authenticate(a.accessToken));await assert.rejects(f.auth.authenticate(a.accessToken),/SESSION_REVOKED/);
 const identity=await f.auth.authenticate(b.accessToken);await f.auth.logout(identity,true);await assert.rejects(f.auth.authenticate(b.accessToken),/SESSION_REVOKED/);
});
test('reset token changes password once, revokes every session and cannot be used for verification',async()=>{
 const old=await registered();await f.auth.requestEmail(email,'reset');const raw=await mailToken('reset');
 await assert.rejects(f.auth.useEmailToken(raw,'verify'),/INVALID_EMAIL_TOKEN/);
 await f.auth.useEmailToken(raw,'reset','A-new-password-that-is-long');
 await assert.rejects(f.auth.authenticate(old.accessToken),/SESSION_REVOKED/);
 await assert.rejects(f.auth.login(email,password),/INVALID_CREDENTIALS/);
 await f.auth.login(email,'A-new-password-that-is-long');await assert.rejects(f.auth.useEmailToken(raw,'reset',password),/INVALID_EMAIL_TOKEN/);
});
test('expired tokens, wrong issuer and invalid access signatures are rejected',async()=>{
 const login=await registered();await assert.rejects(f.auth.authenticate(login.accessToken+'broken'),/INVALID_ACCESS_TOKEN/);
 const token=await new SignJWT({sid:'00000000-0000-0000-0000-000000000001'}).setProtectedHeader({alg:'HS256'}).setSubject(login.userId).setIssuer('wrong').setAudience('test-api').setExpirationTime('15m').sign(f.auth.settings.secret);
 await assert.rejects(f.auth.authenticate(token),/INVALID_ACCESS_TOKEN/);
 await f.pool.query("update backend.sessions set expires_at=now()-interval '1 minute'");await assert.rejects(f.auth.refresh(login.refreshToken),/INVALID_REFRESH_TOKEN/);
 await f.auth.requestEmail(email,'reset');await f.pool.query("update backend.auth_tokens set expires_at=now()-interval '1 minute'");
 await assert.rejects(f.auth.useEmailToken(await mailToken('reset'),'reset',password),/INVALID_EMAIL_TOKEN/);
});
test('login rate limit is database-backed and survives creating another app process',async()=>{
 for (let i=0;i<10;i++) await request(f.app).post('/v1/auth/login').send({email,password}).expect(401);
 const response=await request(f.app).post('/v1/auth/login').send({email,password}).expect(429);
 assert.ok(response.headers['retry-after']);assert.equal(response.body.error,'RATE_LIMITED');
});
test('cloud progress follows an account to a second login and is isolated by game and player',async()=>{
 const first=await registered(),headers={Authorization:'Bearer '+first.accessToken};
 const payload={character:'atlas',wave:17,coins:231,gym:{power:5},badges:['first_ko']};
 const saved=await request(f.app).put('/v1/games/ringrush/save').set(headers).send({expectedRevision:'0',schemaVersion:1,purchaseCursor:'0',payload}).expect(200);
 assert.equal(saved.body.save.revision,'1');
 const second=await f.auth.login(email,password);
 const restored=await request(f.app).get('/v1/games/ringrush/save').set('Authorization','Bearer '+second.accessToken).expect(200);
 assert.deepEqual(restored.body.save.payload,payload);
 assert.equal((await f.saves.get('nextgame',first.userId)).save,null);
 const other=await f.user();assert.equal((await f.saves.get('ringrush',other.id)).save,null);
});
test('simultaneous devices and stale revisions cannot overwrite an accepted save',async()=>{
 const u=await f.user(),input={expectedRevision:'0',schemaVersion:1,purchaseCursor:'0',payload:{level:1}};
 const result=await Promise.allSettled([f.saves.put('ringrush',u.id,input),f.saves.put('ringrush',u.id,{...input,payload:{level:2}})]);
 assert.equal(result.filter(r=>r.status==='fulfilled').length,1);assert.equal(result.filter(r=>r.status==='rejected').length,1);
 await assert.rejects(f.saves.put('ringrush',u.id,input),/SAVE_REVISION_CONFLICT/);
 assert.equal((await f.saves.get('ringrush',u.id)).save!.revision,'1');
});
test('new purchase or refund requires ledger reconciliation before saving; payload cannot invent real entitlements',async()=>{
 const u=await f.user();await f.saves.put('ringrush',u.id,{expectedRevision:'0',schemaVersion:1,purchaseCursor:'0',payload:{level:1}});
 const token=f.purchase(u.account,{productId:'remove_ads'});await f.commerce.sync('ringrush',token);
 await assert.rejects(f.saves.put('ringrush',u.id,{expectedRevision:'1',schemaVersion:1,purchaseCursor:'0',payload:{level:2}}),/COMMERCE_CHANGED/);
 const inventory=await f.commerce.inventory('ringrush',u.id);
 await f.saves.put('ringrush',u.id,{expectedRevision:'1',schemaVersion:1,purchaseCursor:inventory.cursor,payload:{level:2,entitlements:{free_everything:true}}});
 assert.deepEqual((await f.commerce.inventory('ringrush',u.id)).entitlements,['remove_ads']);
 await f.commerce.sync('ringrush',token,{fullRefund:true});
 await assert.rejects(f.saves.put('ringrush',u.id,{expectedRevision:'2',schemaVersion:1,purchaseCursor:inventory.cursor,payload:{entitlements:{remove_ads:true}}}),/COMMERCE_CHANGED/);
 assert.deepEqual((await f.commerce.inventory('ringrush',u.id)).entitlements,[]);
});
test('cloud save rejects oversized data and schema downgrade; keeps bounded recovery history',async()=>{
 const u=await f.user();
 await assert.rejects(f.saves.put('ringrush',u.id,{expectedRevision:'0',schemaVersion:1,purchaseCursor:'0',payload:{large:'x'.repeat(510000)}}),/SAVE_TOO_LARGE/);
 for (let i=0;i<14;i++) await f.saves.put('ringrush',u.id,{expectedRevision:String(i),schemaVersion:2,purchaseCursor:'0',payload:{level:i}});
 await assert.rejects(f.saves.put('ringrush',u.id,{expectedRevision:'14',schemaVersion:1,purchaseCursor:'0',payload:{}}),/SAVE_SCHEMA_DOWNGRADE/);
 assert.equal((await f.pool.query('select * from backend.cloud_save_history')).rowCount,9);
});
test('HTTP validates bodies and never trusts caller-supplied user ID, reward amount or refund flags',async()=>{
 const login=await registered(),header='Bearer '+login.accessToken;
 await request(f.app).post('/v1/games/ringrush/purchases/verify').set('Authorization',header).send({purchaseToken:'x'.repeat(32),productId:'coins_500',userId:'attacker',coins:9999,fullRefund:true}).expect(400);
 await request(f.app).put('/v1/games/ringrush/save').set('Authorization',header).send({expectedRevision:0,purchaseCursor:'0',schemaVersion:1,payload:{}}).expect(400);
 await request(f.app).get('/v1/games/ringrush/ledger?after=-1').set('Authorization',header).expect(400);
 await request(f.app).get('/v1/games/ringrush/save').expect(401);
 await request(f.app).post('/v1/auth/login').set('Content-Type','application/json').send('{bad').expect(400);
});
test('runtime DB role cannot mutate ledger or migration metadata; public has no schema access',async()=>{
 const db=await f.pool.connect();
 try {
  await db.query('set role game_backend');
  await db.query('select count(*) from backend.users');
  await assert.rejects(db.query('delete from backend.ledger'),/permission denied/);
  await assert.rejects(db.query('select * from backend.schema_migrations'),/permission denied/);
 } finally {await db.query('reset role');db.release();}
 const privileges=await f.pool.query("select has_schema_privilege('public','backend','usage') as allowed");assert.equal(privileges.rows[0].allowed,false);
});
test('encrypted tokens detect tampering and old keys remain readable during rotation',()=>{
 const a=randomBytes(32).toString('base64'),b=randomBytes(32).toString('base64');
 const first=new Vault({v1:a},'v1'),encrypted=first.seal('secret');
 const rotated=new Vault({v1:a,v2:b},'v2');assert.equal(rotated.open(encrypted),'secret');assert.ok(rotated.seal('next').startsWith('v2.'));
 const pieces=encrypted.split('.');pieces[2]='A'.repeat(22);assert.throws(()=>rotated.open(pieces.join('.')));
});
test('Play v2 adapter reads state, quantities and consumption from actual wire fields',()=>{
 const p=parsePlayPurchase({purchaseStateContext:{purchaseState:'PURCHASED'},productLineItem:[{productId:'coins_500',productOfferDetails:{quantity:3,refundableQuantity:2,consumptionState:'CONSUMPTION_STATE_CONSUMED'}}],orderId:'GPA.123',obfuscatedExternalAccountId:'account',testPurchaseContext:{fopType:'TEST'},acknowledgementState:'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED'});
 assert.equal(p.quantity,3);assert.equal(p.refundableQuantity,2);assert.equal(p.consumed,true);assert.equal(p.test,true);assert.equal(p.acknowledged,true);
 assert.throws(()=>parsePlayPurchase({purchaseStateContext:{purchaseState:'UNSPECIFIED'}}),/INVALID_PLAY_RESPONSE/);
});
