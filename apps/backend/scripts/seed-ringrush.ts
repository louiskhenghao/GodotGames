import {z} from 'zod';
import {tx} from '../src/db.js';
import {scriptPool} from './database.js';
const packageName=z.string().regex(/^[a-zA-Z][\w]*(\.[a-zA-Z][\w]*)+$/).refine(v=>!v.startsWith('com.example.')).parse(process.env.RINGRUSH_ANDROID_PACKAGE);
const subscription=process.env.RINGRUSH_PUBSUB_SUBSCRIPTION??null;
if (subscription && !/^projects\/[^/]+\/subscriptions\/[^/]+$/.test(subscription)) throw new Error('Invalid Pub/Sub subscription');
const pool=scriptPool();
try {
  await tx(pool,async db=>{
    const old=(await db.query<{android_package:string}>('select android_package from backend.games where id=$1',['ringrush'])).rows[0];
    if (old && old.android_package!==packageName) throw new Error('Existing game package is immutable; use a new game ID for a different app');
    await db.query(`insert into backend.games(id,android_package,enabled,allow_test_purchases,pubsub_subscription) values('ringrush',$1,$2,$3,$4)
      on conflict(id) do update set enabled=excluded.enabled,allow_test_purchases=excluded.allow_test_purchases,pubsub_subscription=excluded.pubsub_subscription`,
      [packageName,process.env.RINGRUSH_ENABLED==='true',process.env.RINGRUSH_ALLOW_TEST_PURCHASES==='true',subscription]);
    for (const [id,kind,units,currency,entitlement] of [
      ['coins_500','consumable',500,'coins',null],['coins_1500','consumable',1500,'coins',null],['coins_4000','consumable',4000,'coins',null],
      ['remove_ads','non_consumable',0,null,'remove_ads'],['gold_gloves','non_consumable',0,null,'gold_gloves']
    ]) await db.query(`insert into backend.products(game_id,id,kind,units,currency,entitlement) values('ringrush',$1,$2,$3,$4,$5) on conflict(game_id,id) do nothing`,[id,kind,units,currency,entitlement]);
  });
  console.log('RingRush catalog configured. Existing product rewards were not overwritten.');
} finally {await pool.end();}
