import {randomBytes,randomUUID} from 'node:crypto';
import {createPool} from '../src/db.js';
import {migrate} from '../scripts/migrations.js';
import {Vault} from '../src/crypto.js';
import {Queue} from '../src/queue.js';
import {Auth} from '../src/auth.js';
import {Commerce} from '../src/commerce.js';
import {CloudSaves} from '../src/cloud-saves.js';
import {Notifications} from '../src/notifications.js';
import type {Game,PlayProvider,PlayPurchase,VoidedPage} from '../src/google-play.js';
import {createApp} from '../src/app.js';
import {AppError} from '../src/errors.js';
export const databaseUrl=process.env.TEST_DATABASE_URL??'postgresql://iap_test:local-test-only@127.0.0.1:55439/iap_test';
const target=new URL(databaseUrl);
if (!['127.0.0.1','localhost'].includes(target.hostname) || !target.pathname.endsWith('_test')) throw new Error('Integration tests require a disposable localhost *_test database');
export class FakePlay implements PlayProvider {
  data=new Map<string,PlayPurchase>();calls=0;finalizations:Array<{token:string;consume:boolean}>=[];failFinalize=false;
  voidedPages:VoidedPage[]=[{items:[]}];
  async get(game:Game,token:string) {this.calls++;const p=this.data.get(`${game.id}:${token}`);if (!p) throw new AppError(422,'PLAY_PURCHASE_UNAVAILABLE');return structuredClone(p);}
  async finalize(game:Game,token:string,_product:string,consume:boolean) {
    if (this.failFinalize) throw new AppError(503,'PLAY_UNAVAILABLE');
    this.finalizations.push({token,consume});const p=this.data.get(`${game.id}:${token}`)!;
    if (consume) p.consumed=true;else p.acknowledged=true;
  }
  async voided(_game:Game,_start:number,_end:number,page?:string) {return this.voidedPages[page?Number(page):0]!;}
}
export async function fixture() {
  const pool=createPool(databaseUrl,false);
  await migrate(pool);
  await pool.query('truncate backend.ledger,backend.purchases,backend.cloud_save_history,backend.cloud_saves,backend.game_accounts,backend.products,backend.games,backend.jobs,backend.auth_tokens,backend.sessions,backend.users,backend.rate_limits restart identity cascade');
  const queue=new Queue(pool,new Vault({v1:randomBytes(32).toString('base64')},'v1'));
  const auth=new Auth(pool,queue,{secret:randomBytes(32),issuer:'test',audience:'test-api',publicUrl:'http://localhost:3000'});
  const play=new FakePlay(),commerce=new Commerce(pool,play,queue),saves=new CloudSaves(pool,commerce),notifications=new Notifications(commerce,queue);
  const logs:object[]=[];
  const app=createApp({auth,commerce,saves,notifications,verifyPush:async token=>{if (token!=='trusted-google') throw new AppError(401,'INVALID_PUSH_IDENTITY');},origins:['http://localhost:8769'],trustProxy:0,log:value=>logs.push(value)});
  for (const id of ['ringrush','nextgame']) {
    await pool.query(`insert into backend.games(id,android_package,enabled,allow_test_purchases,pubsub_subscription) values($1,$2,true,true,$3)`,[id,'dev.test.'+id,'projects/test/subscriptions/'+id]);
    for (const [sku,kind,units,currency,entitlement] of [['coins_500','consumable',500,'coins',null],['remove_ads','non_consumable',0,null,'remove_ads'],['gold_gloves','non_consumable',0,null,'gold_gloves']]) {
      await pool.query('insert into backend.products(game_id,id,kind,units,currency,entitlement) values($1,$2,$3,$4,$5,$6)',[id,sku,kind,units,currency,entitlement]);
    }
  }
  async function user(verified=true) {
    const id=randomUUID();await pool.query(`insert into backend.users(id,email,password_hash,email_verified_at) values($1,$2,'test-only',case when $3 then now() else null end)`,[id,id+'@example.test',verified]);
    const context=await commerce.context('ringrush',id);
    return {id,account:context.obfuscatedAccountId};
  }
  function purchase(account:string,overrides:Partial<PlayPurchase>={},game='ringrush') {
    const token=randomBytes(32).toString('hex');
    play.data.set(game+':'+token,{productId:'coins_500',state:'PURCHASED',quantity:1,refundableQuantity:1,accountId:account,orderId:'GPA.'+randomUUID(),test:true,acknowledged:false,consumed:false,...overrides});return token;
  }
  return {pool,queue,auth,play,commerce,saves,notifications,app,logs,user,purchase,close:()=>pool.end()};
}
export function notification(token:string,override:object={},messageId='message-1') {
  return {subscription:'projects/test/subscriptions/ringrush',message:{messageId,data:Buffer.from(JSON.stringify({packageName:'dev.test.ringrush',oneTimeProductNotification:{purchaseToken:token,sku:'coins_500'},...override})).toString('base64')}};
}
