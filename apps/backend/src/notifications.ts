import {z} from 'zod';
import {invariant} from './errors.js';
import {Commerce} from './commerce.js';
import {hash} from './crypto.js';
import {Queue} from './queue.js';
import type {Game} from './google-play.js';
const envelopeSchema=z.object({subscription:z.string().min(1),message:z.object({messageId:z.string().min(1).max(128),data:z.string().min(1).max(60000)})});
const eventSchema=z.object({packageName:z.string().min(1),
  oneTimeProductNotification:z.object({purchaseToken:z.string().min(1).max(4096),sku:z.string().min(1)}).optional(),
  voidedPurchaseNotification:z.object({purchaseToken:z.string().min(1).max(4096),productType:z.number().int(),refundType:z.number().int()}).optional(),
  testNotification:z.object({}).optional(), subscriptionNotification:z.unknown().optional(),pendingRefundReviewNotification:z.unknown().optional()
});
export type PlayEvent=z.infer<typeof eventSchema>;
export class Notifications {
  constructor(readonly commerce:Commerce,readonly queue:Queue) {}
  async accept(raw:unknown) {
    const envelope=envelopeSchema.safeParse(raw);invariant(envelope.success,400,'INVALID_NOTIFICATION');
    let value:unknown;
    try {value=JSON.parse(Buffer.from(envelope.data.message.data,'base64').toString('utf8'));} catch {invariant(false,400,'INVALID_NOTIFICATION');}
    const event=eventSchema.safeParse(value);invariant(event.success,400,'INVALID_NOTIFICATION');
    const body=event.data;
    invariant([body.oneTimeProductNotification,body.voidedPurchaseNotification,body.testNotification,body.subscriptionNotification,body.pendingRefundReviewNotification].filter(v=>v!==undefined).length===1,400,'INVALID_NOTIFICATION');
    const {rows}=await this.commerce.pool.query<Game>('select * from backend.games where android_package=$1 and enabled=true',[body.packageName]);
    const game=rows[0];invariant(game && game.pubsub_subscription===envelope.data.subscription,403,'NOTIFICATION_GAME_MISMATCH');
    // HTTP ACK is returned only after a durable inbox/outbox insert, never after fire-and-forget.
    await this.queue.add(this.commerce.pool,'notification',`rtdn:${game.id}:${envelope.data.message.messageId}`,{gameId:game.id,event:body});
  }
  async process(gameId:string,event:PlayEvent) {
    if (event.testNotification) return;
    if (event.oneTimeProductNotification) {
      const p=event.oneTimeProductNotification;
      await this.commerce.sync(gameId,p.purchaseToken,{productId:p.sku});return;
    }
    if (event.voidedPurchaseNotification) {
      const p=event.voidedPurchaseNotification;
      invariant(p.productType===2,422,'SUBSCRIPTIONS_NOT_SUPPORTED');
      invariant([1,2].includes(p.refundType),422,'UNKNOWN_REFUND_TYPE');
      // Full refund is an authenticated terminal signal; still query Play for product/account data.
      await this.commerce.sync(gameId,p.purchaseToken,{fullRefund:p.refundType===1});return;
    }
    // These events need a separate subscription/refund-review workflow; make them visible to ops.
    invariant(false,422,'UNSUPPORTED_PLAY_EVENT');
  }
  async reconcile(gameId:string) {
    const game=await this.commerce.game(gameId),end=Date.now()-120000,start=end-29*86400000;
    let page:string|undefined;
    for (let i=0;i<100;i++) {
      const result=await this.commerce.play.voided(game,start,end,page);
      for (const item of result.items) await this.queue.add(this.commerce.pool,'sync',`voided:${gameId}:${hash(item.token)}:${Math.floor(end/21600000)}`,{gameId,token:item.token,fullRefund:item.full});
      page=result.next;
      if (!page) {await this.commerce.pool.query('update backend.games set last_reconciled_at=now() where id=$1',[gameId]);return;}
    }
    invariant(false,503,'RECONCILIATION_PAGE_LIMIT');
  }
}
