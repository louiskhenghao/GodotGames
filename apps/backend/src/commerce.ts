import {randomUUID} from 'node:crypto';
import {randomToken,hash} from './crypto.js';
import {tx,lock,type Pool,type DB} from './db.js';
import {AppError,invariant} from './errors.js';
import {Queue} from './queue.js';
import type {Game,PlayProvider} from './google-play.js';
interface Product {game_id:string;id:string;kind:'consumable'|'non_consumable';units:string;currency:string|null;entitlement:string|null;active:boolean;}
interface Purchase extends Omit<Product,'id'> {
 id:string;user_id:string;product_id:string;token_hash:string;token_cipher:string;state:string;quantity:number;
 granted_quantity:number;revoked_quantity:number;finalized_at:Date|null;test_purchase:boolean;
}
export class Commerce {
  constructor(readonly pool:Pool,readonly play:PlayProvider,readonly queue:Queue) {}
  async game(id:string,db:DB=this.pool):Promise<Game> {
    const result=await db.query<Game>('select * from backend.games where id=$1 and enabled=true',[id]);
    invariant(result.rows[0],404,'GAME_UNAVAILABLE');return result.rows[0];
  }
  async context(gameId:string,userId:string) {
    const game=await this.game(gameId);
    const result=await this.pool.query<{billing_id:string}>(`insert into backend.game_accounts(game_id,user_id,billing_id) values($1,$2,$3)
      on conflict(game_id,user_id) do update set user_id=excluded.user_id returning billing_id`,[gameId,userId,randomToken()]);
    const products=await this.pool.query(`select id,kind,currency,units,entitlement from backend.products where game_id=$1 and active=true order by id`,[gameId]);
    return {gameId,androidPackage:game.android_package,obfuscatedAccountId:result.rows[0]!.billing_id,products:products.rows};
  }
  async sync(gameId:string,token:string,options:{userId?:string;productId?:string;fullRefund?:boolean}={}) {
    return tx(this.pool,async db=>{
      // Fetch Google AFTER taking the token lock: concurrent stale reads cannot undo a refund.
      await lock(db,'purchase:'+hash(token));
      const game=await this.game(gameId,db);
      const old=(await db.query<Purchase>('select * from backend.purchases where token_hash=$1',[hash(token)])).rows[0];
      invariant(!old || old.game_id===gameId,409,'PURCHASE_GAME_MISMATCH');
      invariant(!old || !options.userId || old.user_id===options.userId,409,'PURCHASE_OWNER_MISMATCH');
      const verified=await this.play.get(game,token).catch(async error=>{
        // A verified full-void event can arrive after Google's token lookup retention.
        // Only an already-owned, previously verified purchase may use this fallback.
        if (!old || !options.fullRefund || !(error instanceof AppError) || error.code!=='PLAY_PURCHASE_UNAVAILABLE') throw error;
        const account=(await db.query<{billing_id:string}>('select billing_id from backend.game_accounts where game_id=$1 and user_id=$2',[old.game_id,old.user_id])).rows[0]!;
        return {productId:old.product_id,state:'CANCELLED' as const,quantity:old.quantity,refundableQuantity:0,accountId:account.billing_id,
          orderId:undefined,test:old.test_purchase,acknowledged:!!old.finalized_at,consumed:old.kind==='consumable' && !!old.finalized_at};
      });
      invariant(verified.accountId,409,'PURCHASE_ACCOUNT_MISSING');
      const account=(await db.query<{user_id:string}>(`select user_id from backend.game_accounts where game_id=$1 and billing_id=$2`,[gameId,verified.accountId])).rows[0];
      invariant(account,409,'PURCHASE_ACCOUNT_UNKNOWN');
      const userId=account.user_id;
      invariant((!options.userId || userId===options.userId) && (!old || old.user_id===userId),409,'PURCHASE_OWNER_MISMATCH');
      invariant(!options.productId || verified.productId===options.productId,409,'PURCHASE_PRODUCT_MISMATCH');
      invariant(!verified.test || game.allow_test_purchases,403,'TEST_PURCHASE_DISABLED');
      const product=(await db.query<Product>('select * from backend.products where game_id=$1 and id=$2',[gameId,verified.productId])).rows[0];
      invariant(product && (product.active || old),422,'PRODUCT_UNAVAILABLE');
      invariant(!old || (old.product_id===verified.productId && old.quantity===verified.quantity),409,'PURCHASE_CHANGED');
      invariant(product.kind!=='non_consumable' || verified.quantity===1,422,'INVALID_NONCONSUMABLE_QUANTITY');
      // A previously consumed token first presented to this backend may already have paid elsewhere.
      invariant(old || options.fullRefund || product.kind!=='consumable' || !verified.consumed,409,'CONSUMED_PURCHASE_REQUIRES_MIGRATION');
      // This second lock orders all account ledger entries by commit order, making cursors safe.
      await lock(db,`account:${gameId}:${userId}`);
      let purchase=old;
      if (!purchase) {
        purchase=(await db.query<Purchase>(`insert into backend.purchases
          (id,game_id,user_id,product_id,token_hash,token_cipher,state,kind,units,currency,entitlement,quantity,test_purchase,order_id)
          values($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14) returning *`,
          [randomUUID(),gameId,userId,product.id,hash(token),this.queue.vault.seal(token),verified.state,product.kind,product.units,product.currency,product.entitlement,verified.quantity,verified.test,verified.orderId??null])).rows[0]!;
      }
      let granted=purchase.granted_quantity,revoked=purchase.revoked_quantity;
      // A cancellation is terminal. Refunds can only reduce remaining quantity, never re-grant it.
      const cancelled=options.fullRefund || verified.state==='CANCELLED' || old?.state==='CANCELLED' || (verified.state==='PURCHASED' && verified.refundableQuantity===0);
      if (!cancelled && verified.state==='PURCHASED' && granted===0) {
        granted=purchase.quantity;
        await this.entry(db,purchase,'purchase',granted,`grant:${purchase.id}`);
      }
      const targetRevoked=cancelled?granted:Math.max(revoked,granted-Math.min(granted,verified.refundableQuantity??granted));
      if (targetRevoked>revoked) {
        await this.entry(db,purchase,'refund',-(targetRevoked-revoked),`refund:${purchase.id}:${targetRevoked}`);revoked=targetRevoked;
      }
      const state=cancelled?'CANCELLED':(granted>0?'PURCHASED':verified.state);
      const finalized=verified.consumed || (purchase.kind==='non_consumable' && verified.acknowledged);
      await db.query(`update backend.purchases set state=$2,granted_quantity=$3,revoked_quantity=$4,refundable_quantity=$5,
        finalized_at=case when $6 then coalesce(finalized_at,now()) else finalized_at end,
        order_id=coalesce(order_id,$7),checked_at=now(),next_check_at=now()+case when $2='PENDING' then interval '5 minutes' else interval '24 hours' end where id=$1`,
        [purchase.id,state,granted,revoked,verified.refundableQuantity??null,finalized,verified.orderId??null]);
      if (state==='PURCHASED' && !finalized && !purchase.finalized_at) await this.queue.add(db,'finalize',`finalize:${purchase.id}`,{purchaseId:purchase.id});
      return {purchaseId:purchase.id,productId:purchase.product_id,state,quantity:purchase.quantity,grantedQuantity:granted,revokedQuantity:revoked,finalization:state!=='PURCHASED'?'not_required':(finalized || purchase.finalized_at?'complete':'queued')};
    });
  }
  private async entry(db:DB,p:Purchase,reason:'purchase'|'refund',quantity:number,key:string) {
    await db.query(`insert into backend.ledger(purchase_id,game_id,user_id,event_key,reason,currency,amount,entitlement,quantity_delta)
      values($1,$2,$3,$4,$5,$6,$7,$8,$9)`,[p.id,p.game_id,p.user_id,key,reason,p.currency,(BigInt(p.units)*BigInt(quantity)).toString(),p.entitlement,quantity]);
  }
  async inventory(gameId:string,userId:string) {
    await this.game(gameId);
    return tx(this.pool,async db=>{
      await lock(db,`account:${gameId}:${userId}`);
      const currencies=await db.query(`select currency,sum(amount)::text as "netGranted" from backend.ledger where game_id=$1 and user_id=$2 and currency is not null group by currency`,[gameId,userId]);
      const entitlements=await db.query<{entitlement:string}>(`select entitlement from backend.purchases where game_id=$1 and user_id=$2 and kind='non_consumable' and granted_quantity>revoked_quantity group by entitlement order by entitlement`,[gameId,userId]);
      const managed=await db.query<{entitlement:string}>("select distinct entitlement from backend.products where game_id=$1 and kind='non_consumable'",[gameId]);
      const cursor=await db.query<{cursor:string}>('select coalesce(max(sequence),0)::text as cursor from backend.ledger where game_id=$1 and user_id=$2',[gameId,userId]);
      return {gameId,userId,managedEntitlements:managed.rows.map(e=>e.entitlement),entitlements:entitlements.rows.map(e=>e.entitlement),purchaseCredits:currencies.rows,cursor:cursor.rows[0]!.cursor};
    });
  }
  async ledger(gameId:string,userId:string,after:string) {
    await this.game(gameId);
    const result=await this.pool.query(`select sequence::text,event_key as "eventId",purchase_id as "purchaseId",reason,currency,amount::text,entitlement,quantity_delta as "quantityDelta",created_at as "createdAt"
      from backend.ledger where game_id=$1 and user_id=$2 and sequence>$3::bigint order by backend.ledger.sequence limit 101`,[gameId,userId,after]);
    const entries=result.rows.slice(0,100);
    return {entries,nextCursor:entries.at(-1)?.sequence??after,hasMore:result.rows.length>100};
  }
  async finalize(purchaseId:string) {
    const row=(await this.pool.query<Purchase>('select * from backend.purchases where id=$1',[purchaseId])).rows[0];
    invariant(row,404,'PURCHASE_NOT_FOUND');
    await tx(this.pool,async db=>{
      await lock(db,'purchase:'+row.token_hash);
      const p=(await db.query<Purchase>('select * from backend.purchases where id=$1',[purchaseId])).rows[0]!;
      if (p.state!=='PURCHASED' || p.finalized_at) return;
      const game=await this.game(p.game_id,db),token=this.queue.vault.open(p.token_cipher);
      const latest=await this.play.get(game,token);
      if (latest.state!=='PURCHASED') {
        await this.queue.add(db,'sync',`finalize-state:${p.id}`,{gameId:p.game_id,token});return;
      }
      if (!(p.kind==='consumable'?latest.consumed:latest.acknowledged)) await this.play.finalize(game,token,p.product_id,p.kind==='consumable');
      await db.query('update backend.purchases set finalized_at=now() where id=$1',[p.id]);
    });
  }
  async restore(gameId:string,userId:string,tokens:string[]) {
    const results=[];
    for (const token of [...new Set(tokens)]) {
      try {results.push({tokenHash:hash(token),...await this.sync(gameId,token,{userId})});}
      catch(error) {if (error instanceof AppError && error.status<500) results.push({tokenHash:hash(token),error:error.code}); else throw error;}
    }
    // Known non-consumables are revalidated too, even if Billing returns an empty array after refund.
    const known=await this.pool.query<{token_cipher:string}>(`select token_cipher from backend.purchases where game_id=$1 and user_id=$2 and kind='non_consumable' and state='PURCHASED' limit 101`,[gameId,userId]);
    invariant(known.rows.length<=100,409,'RESTORE_REQUIRES_RECONCILIATION');
    for (const p of known.rows) await this.sync(gameId,this.queue.vault.open(p.token_cipher),{userId});
    return {results,inventory:await this.inventory(gameId,userId)};
  }
}
