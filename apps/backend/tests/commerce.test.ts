import {test,beforeEach,afterEach} from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import {fixture,notification} from './helpers.js';
import {Worker} from '../src/worker.js';
import {hash} from '../src/crypto.js';
let f:Awaited<ReturnType<typeof fixture>>;
beforeEach(async()=>{f=await fixture();});afterEach(async()=>{await f.close();});
test('concurrent verification grants exactly once and produces one durable finalization',async()=>{
 const u=await f.user(),token=f.purchase(u.account);
 const results=await Promise.all(Array.from({length:8},()=>f.commerce.sync('ringrush',token,{userId:u.id,productId:'coins_500'})));
 assert.equal(new Set(results.map(r=>r.purchaseId)).size,1);
 assert.equal((await f.commerce.inventory('ringrush',u.id)).purchaseCredits[0].netGranted,'500');
 assert.equal((await f.pool.query('select * from backend.ledger')).rowCount,1);
 assert.equal((await f.pool.query('select * from backend.jobs')).rowCount,1);
 const row=(await f.pool.query('select token_cipher from backend.purchases')).rows[0];assert.ok(!row.token_cipher.includes(token));assert.equal(f.queue.vault.open(row.token_cipher),token);
});
test('pending purchases grant nothing; completion grants once; cancellation never grants',async()=>{
 const u=await f.user(),token=f.purchase(u.account,{state:'PENDING'});
 assert.equal((await f.commerce.sync('ringrush',token,{userId:u.id})).state,'PENDING');
 assert.equal((await f.commerce.inventory('ringrush',u.id)).purchaseCredits.length,0);
 f.play.data.get('ringrush:'+token)!.state='PURCHASED';await f.commerce.sync('ringrush',token,{userId:u.id});
 const cancelled=f.purchase(u.account,{state:'CANCELLED'});await f.commerce.sync('ringrush',cancelled,{userId:u.id});
 assert.equal((await f.commerce.inventory('ringrush',u.id)).purchaseCredits[0].netGranted,'500');
});
test('wrong owner, mismatched product, missing account and disabled test cards cannot grant',async()=>{
 const a=await f.user(),b=await f.user(),token=f.purchase(a.account);
 await assert.rejects(f.commerce.sync('ringrush',token,{userId:b.id}),/PURCHASE_OWNER_MISMATCH/);
 await assert.rejects(f.commerce.sync('ringrush',token,{userId:a.id,productId:'remove_ads'}),/PURCHASE_PRODUCT_MISMATCH/);
 const missing=f.purchase(a.account,{accountId:undefined});await assert.rejects(f.commerce.sync('ringrush',missing,{userId:a.id}),/PURCHASE_ACCOUNT_MISSING/);
 await f.pool.query('update backend.games set allow_test_purchases=false');
 await assert.rejects(f.commerce.sync('ringrush',token,{userId:a.id}),/TEST_PURCHASE_DISABLED/);
 assert.equal((await f.pool.query('select * from backend.ledger')).rowCount,0);
});
test('same token cannot be replayed across games or users; same SKU is game-scoped',async()=>{
 const a=await f.user(),b=await f.user(),token=f.purchase(a.account);await f.commerce.sync('ringrush',token,{userId:a.id});
 await assert.rejects(f.commerce.sync('ringrush',token,{userId:b.id}),/PURCHASE_OWNER_MISMATCH/);
 await assert.rejects(f.commerce.sync('nextgame',token,{userId:a.id}),/PURCHASE_GAME_MISMATCH/);
 const next=await f.commerce.context('nextgame',a.id);assert.notEqual(next.obfuscatedAccountId,a.account);
 const nextToken=f.purchase(next.obfuscatedAccountId,{},'nextgame');await f.commerce.sync('nextgame',nextToken,{userId:a.id});
 assert.equal((await f.commerce.inventory('nextgame',a.id)).purchaseCredits[0].netGranted,'500');
 assert.equal((await f.commerce.inventory('ringrush',b.id)).purchaseCredits.length,0);
});
test('partial and full refunds append only the delta, tolerate duplicates and cannot resurrect',async()=>{
 const u=await f.user(),token=f.purchase(u.account,{quantity:3,refundableQuantity:3});await f.commerce.sync('ringrush',token);
 const play=f.play.data.get('ringrush:'+token)!;play.refundableQuantity=2;await f.commerce.sync('ringrush',token);await f.commerce.sync('ringrush',token);
 assert.equal((await f.commerce.inventory('ringrush',u.id)).purchaseCredits[0].netGranted,'1000');
 play.refundableQuantity=3;await f.commerce.sync('ringrush',token); // stale API response
 assert.equal((await f.commerce.inventory('ringrush',u.id)).purchaseCredits[0].netGranted,'1000');
 await f.commerce.sync('ringrush',token,{fullRefund:true});await f.commerce.sync('ringrush',token);
 assert.equal((await f.commerce.inventory('ringrush',u.id)).purchaseCredits[0].netGranted,'0');
 assert.deepEqual((await f.commerce.ledger('ringrush',u.id,'0')).entries.map(e=>e.amount),['1500','-500','-1000']);
 await assert.rejects(f.pool.query('update backend.ledger set amount=999'),/append-only/);
});
test('refunded purchase cannot remove an independently repurchased nonconsumable',async()=>{
 const u=await f.user(),first=f.purchase(u.account,{productId:'remove_ads'}),second=f.purchase(u.account,{productId:'remove_ads'});
 await f.commerce.sync('ringrush',first);await f.commerce.sync('ringrush',second);await f.commerce.sync('ringrush',first,{fullRefund:true});
 assert.deepEqual((await f.commerce.inventory('ringrush',u.id)).entitlements,['remove_ads']);
 await f.commerce.sync('ringrush',second,{fullRefund:true});assert.deepEqual((await f.commerce.inventory('ringrush',u.id)).entitlements,[]);
});
test('restore does not re-grant coins and empty Billing result still revokes known refunded entitlement',async()=>{
 const u=await f.user(),coins=f.purchase(u.account),ads=f.purchase(u.account,{productId:'remove_ads'});
 await f.commerce.sync('ringrush',coins);await f.commerce.sync('ringrush',ads);
 await f.commerce.restore('ringrush',u.id,[coins,coins,ads]);
 assert.equal((await f.commerce.inventory('ringrush',u.id)).purchaseCredits[0].netGranted,'500');
 f.play.data.get('ringrush:'+ads)!.state='CANCELLED';
 assert.deepEqual((await f.commerce.restore('ringrush',u.id,[])).inventory.entitlements,[]);
});
test('crash/retry after Google consume does not grant or consume twice',async()=>{
 const u=await f.user(),token=f.purchase(u.account);const result=await f.commerce.sync('ringrush',token);
 f.play.failFinalize=true;await assert.rejects(f.commerce.finalize(result.purchaseId),/PLAY_UNAVAILABLE/);
 assert.equal((await f.commerce.inventory('ringrush',u.id)).purchaseCredits[0].netGranted,'500');
 f.play.failFinalize=false;f.play.data.get('ringrush:'+token)!.consumed=true; // Google committed, process died before local marker.
 await f.commerce.finalize(result.purchaseId);await f.commerce.finalize(result.purchaseId);
 assert.equal(f.play.finalizations.length,0);assert.ok((await f.pool.query('select finalized_at from backend.purchases')).rows[0].finalized_at);
});
test('consumables use consume and permanent products use acknowledge',async()=>{
 const u=await f.user();for (const productId of ['coins_500','remove_ads']) {const token=f.purchase(u.account,{productId});const p=await f.commerce.sync('ringrush',token);await f.commerce.finalize(p.purchaseId);}
 assert.deepEqual(f.play.finalizations.map(p=>p.consume),[true,false]);
});
test('unknown consumed token is quarantined, catalog edits never change an existing refund value',async()=>{
 const u=await f.user(),consumed=f.purchase(u.account,{consumed:true});await assert.rejects(f.commerce.sync('ringrush',consumed),/MIGRATION/);
 const token=f.purchase(u.account);await f.commerce.sync('ringrush',token);
 await f.pool.query("update backend.products set units=9999,active=false where id='coins_500'");
 await f.commerce.sync('ringrush',token,{fullRefund:true});assert.equal((await f.commerce.inventory('ringrush',u.id)).purchaseCredits[0].netGranted,'0');
});
test('authenticated push deduplicates durably and a worker processes it before client callback',async()=>{
 const u=await f.user(),token=f.purchase(u.account),body=notification(token);
 await request(f.app).post('/webhooks/google-play').send(body).expect(401);
 await request(f.app).post('/webhooks/google-play').set('Authorization','Bearer wrong').send(body).expect(401);
 await request(f.app).post('/webhooks/google-play').set('Authorization','Bearer trusted-google').send({...body,subscription:'projects/other/subscriptions/evil'}).expect(403);
 for (let i=0;i<2;i++) await request(f.app).post('/webhooks/google-play').set('Authorization','Bearer trusted-google').send(body).expect(204);
 assert.equal((await f.pool.query('select * from backend.jobs')).rowCount,1);
 const worker=new Worker(f.queue,f.commerce,f.notifications,async()=>{},()=>{});await worker.once();await worker.once();
 assert.equal((await f.commerce.inventory('ringrush',u.id)).purchaseCredits[0].netGranted,'500');
 await f.commerce.sync('ringrush',token,{userId:u.id});assert.equal((await f.pool.query('select * from backend.ledger')).rowCount,1);
 assert.ok(!JSON.stringify(f.logs).includes(token));
});
test('concurrent workers claim separate jobs; expired lease can retry; failures retain safe codes',async()=>{
 await f.queue.add(f.pool,'finalize','bad-1',{purchaseId:'00000000-0000-0000-0000-000000000001'});
 await f.queue.add(f.pool,'finalize','bad-2',{purchaseId:'00000000-0000-0000-0000-000000000002'});
 const [a,b]=await Promise.all([f.queue.claim(),f.queue.claim()]);assert.ok(a&&b);assert.notEqual(a.id,b.id);
 await f.pool.query("update backend.jobs set lease_until=now()-interval '1 second' where id=$1",[a.id]);const again=await f.queue.claim();assert.equal(again!.id,a.id);
 await f.queue.finish(a);assert.equal((await f.pool.query('select status from backend.jobs where id=$1',[a.id])).rows[0].status,'running');
 await f.queue.fail(again!,new Error('SECRET_TOKEN'));const row=(await f.pool.query('select * from backend.jobs where id=$1',[a.id])).rows[0];assert.equal(row.status,'ready');assert.equal(row.error_code,'INTERNAL_ERROR');
});
test('voided reconciliation paginates, queues every purchase and does not let one failure block the rest',async()=>{
 const u=await f.user(),a=f.purchase(u.account),b=f.purchase(u.account);await f.commerce.sync('ringrush',a);await f.commerce.sync('ringrush',b);
 f.play.voidedPages=[{items:[{token:a,full:true}],next:'1'},{items:[{token:b,full:true}]}];
 await f.notifications.reconcile('ringrush');
 const jobs=await f.pool.query("select * from backend.jobs where kind='sync' order by id");assert.equal(jobs.rowCount,2);
 const worker=new Worker(f.queue,f.commerce,f.notifications,async()=>{},()=>{});
 for (const job of jobs.rows) await worker.dispatch(job);
 assert.equal((await f.commerce.inventory('ringrush',u.id)).purchaseCredits[0].netGranted,'0');
 assert.ok((await f.pool.query("select last_reconciled_at from backend.games where id='ringrush'")).rows[0].last_reconciled_at);
});
test('ledger cursors stay ordered across concurrent tokens and never reveal another account',async()=>{
 const u=await f.user(),other=await f.user();const tokens=Array.from({length:10},()=>f.purchase(u.account));
 await Promise.all(tokens.map(t=>f.commerce.sync('ringrush',t)));
 const list=await f.commerce.ledger('ringrush',u.id,'0');assert.equal(list.entries.length,10);
 assert.equal((await f.commerce.ledger('ringrush',u.id,list.nextCursor)).entries.length,0);
 assert.equal((await f.commerce.ledger('ringrush',other.id,'0')).entries.length,0);
 assert.equal((await f.pool.query('select count(distinct token_hash) from backend.purchases')).rows[0].count,'10');
 assert.equal(hash(tokens[0]!).length,64);
});
test('a failed outbox write rolls back purchase and grant atomically',async()=>{
 const u=await f.user(),token=f.purchase(u.account),original=f.queue.add.bind(f.queue);
 f.queue.add=async()=>{throw new Error('database unavailable');};
 await assert.rejects(f.commerce.sync('ringrush',token));
 assert.equal((await f.pool.query('select * from backend.ledger')).rowCount,0);
 assert.equal((await f.pool.query('select * from backend.purchases')).rowCount,0);
 f.queue.add=original;await f.commerce.sync('ringrush',token);
 assert.equal((await f.commerce.inventory('ringrush',u.id)).purchaseCredits[0].netGranted,'500');
});
test('ledger pagination uses numeric sequence order beyond the first hundred events',async()=>{
 const u=await f.user();
 for (let i=0;i<106;i++) await f.commerce.sync('ringrush',f.purchase(u.account));
 const first=await f.commerce.ledger('ringrush',u.id,'0');assert.equal(first.entries.length,100);assert.equal(first.hasMore,true);
 const second=await f.commerce.ledger('ringrush',u.id,first.nextCursor);assert.equal(second.entries.length,6);assert.equal(second.hasMore,false);
 assert.equal(new Set([...first.entries,...second.entries].map(e=>e.eventId)).size,106);
 assert.equal((await f.commerce.inventory('ringrush',u.id)).cursor,second.nextCursor);
});
test('authenticated full refund still revokes a known order after Google token retention expires',async()=>{
 const u=await f.user(),token=f.purchase(u.account);await f.commerce.sync('ringrush',token);
 f.play.data.delete('ringrush:'+token);
 await assert.rejects(f.commerce.sync('ringrush',token,{userId:u.id}),/PLAY_PURCHASE_UNAVAILABLE/);
 await f.commerce.sync('ringrush',token,{fullRefund:true});
 assert.equal((await f.commerce.inventory('ringrush',u.id)).purchaseCredits[0].netGranted,'0');
 await f.commerce.sync('ringrush',token,{fullRefund:true});assert.equal((await f.pool.query("select * from backend.ledger where reason='refund'")).rowCount,1);
});
test('zero refundable quantity is terminal and is never queued for consumption',async()=>{
 const u=await f.user(),token=f.purchase(u.account,{refundableQuantity:0});
 const result=await f.commerce.sync('ringrush',token);assert.equal(result.state,'CANCELLED');
 assert.equal(result.finalization,'not_required');assert.equal((await f.pool.query('select * from backend.jobs')).rowCount,0);
 f.play.data.get('ringrush:'+token)!.refundableQuantity=1;await f.commerce.sync('ringrush',token);
 assert.equal((await f.commerce.inventory('ringrush',u.id)).purchaseCredits.length,0);
});
