import {GoogleAuth,OAuth2Client} from 'google-auth-library';
import {z} from 'zod';
import {AppError,invariant} from './errors.js';
export interface Game {id:string;android_package:string;enabled:boolean;allow_test_purchases:boolean;pubsub_subscription:string|null;}
export interface PlayPurchase {
  productId:string;state:'PENDING'|'PURCHASED'|'CANCELLED';quantity:number;refundableQuantity?:number;
  accountId?:string;orderId?:string;test:boolean;acknowledged:boolean;consumed:boolean;
}
export interface VoidedPage {items:Array<{token:string;full:boolean}>;next?:string;}
export interface PlayProvider {
  get(game:Game,token:string):Promise<PlayPurchase>;
  finalize(game:Game,token:string,productId:string,consume:boolean):Promise<void>;
  voided(game:Game,start:number,end:number,page?:string):Promise<VoidedPage>;
}
const productSchema=z.object({
  purchaseStateContext:z.object({purchaseState:z.enum(['PURCHASED','PENDING','CANCELLED'])}),
  productLineItem:z.array(z.object({productId:z.string().min(1),productOfferDetails:z.object({
    quantity:z.number().int().min(1).max(1000).optional(),refundableQuantity:z.number().int().min(0).max(1000).optional(),
    consumptionState:z.enum(['CONSUMPTION_STATE_YET_TO_BE_CONSUMED','CONSUMPTION_STATE_CONSUMED']).optional(),
    rentOfferDetails:z.unknown().optional(),preorderOfferDetails:z.unknown().optional()
  }).optional()})).length(1),
  obfuscatedExternalAccountId:z.string().optional(),orderId:z.string().optional(),testPurchaseContext:z.object({}).optional(),
  acknowledgementState:z.enum(['ACKNOWLEDGEMENT_STATE_PENDING','ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED']).optional()
});
export function parsePlayPurchase(raw:unknown):PlayPurchase {
  const parsed=productSchema.safeParse(raw);invariant(parsed.success,502,'INVALID_PLAY_RESPONSE');
  const p=parsed.data,item=p.productLineItem[0]!,offer=item.productOfferDetails;
  invariant(!offer?.rentOfferDetails && !offer?.preorderOfferDetails,422,'UNSUPPORTED_PURCHASE_OPTION');
  invariant(p.purchaseStateContext.purchaseState!=='PURCHASED' || (offer?.consumptionState && p.acknowledgementState),502,'INCOMPLETE_PLAY_RESPONSE');
  const quantity=offer?.quantity??1;
  invariant((offer?.refundableQuantity??quantity)<=quantity,502,'INVALID_PLAY_QUANTITY');
  invariant(p.purchaseStateContext.purchaseState!=='PURCHASED' || !!p.orderId,502,'MISSING_PLAY_ORDER');
  return {productId:item.productId,state:p.purchaseStateContext.purchaseState,quantity,refundableQuantity:offer?.refundableQuantity,
    accountId:p.obfuscatedExternalAccountId,orderId:p.orderId,test:!!p.testPurchaseContext,
    acknowledged:p.acknowledgementState==='ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',consumed:offer?.consumptionState==='CONSUMPTION_STATE_CONSUMED'};
}
const api='https://androidpublisher.googleapis.com/androidpublisher/v3/applications/';
export class GooglePlay implements PlayProvider {
  private auth=new GoogleAuth({scopes:['https://www.googleapis.com/auth/androidpublisher']});
  private async request(path:string,method='GET'):Promise<unknown> {
    // ADC: use a workload identity in production; a mounted key file in local testing.
    const client=await this.auth.getClient();
    try {return (await client.request({url:api+path,method:method as 'GET'|'POST',timeout:10000,retry:false,...(method==='POST'?{data:{}}:{})})).data;}
    catch(error) {
      const status=(error as {response?:{status?:number}}).response?.status;
      if (status===404 || status===410) throw new AppError(422,'PLAY_PURCHASE_UNAVAILABLE');
      if (status===400) throw new AppError(422,'PLAY_REQUEST_REJECTED');
      // 401/403 are service configuration errors, not player authentication failures.
      throw new AppError(503,status===401 || status===403?'PLAY_PERMISSION_ERROR':'PLAY_UNAVAILABLE');
    }
  }
  async get(game:Game,token:string) {return parsePlayPurchase(await this.request(`${encodeURIComponent(game.android_package)}/purchases/productsv2/tokens/${encodeURIComponent(token)}`));}
  async finalize(game:Game,token:string,productId:string,consume:boolean) {
    await this.request(`${encodeURIComponent(game.android_package)}/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(token)}:${consume?'consume':'acknowledge'}`,'POST');
  }
  async voided(game:Game,start:number,end:number,page?:string):Promise<VoidedPage> {
    const query=new URLSearchParams({startTime:String(start),endTime:String(end),type:'0',includeQuantityBasedPartialRefund:'true',maxResults:'1000'});
    if (page) query.set('token',page);
    const schema=z.object({voidedPurchases:z.array(z.object({purchaseToken:z.string().min(1),voidedQuantity:z.number().int().positive().optional()})).optional(),tokenPagination:z.object({nextPageToken:z.string().optional()}).optional()});
    const result=schema.safeParse(await this.request(`${encodeURIComponent(game.android_package)}/purchases/voidedpurchases?${query}`));
    invariant(result.success,502,'INVALID_VOIDED_RESPONSE');
    return {items:(result.data.voidedPurchases??[]).map(v=>({token:v.purchaseToken,full:v.voidedQuantity===undefined})),next:result.data.tokenPagination?.nextPageToken};
  }
}
export class PubSubVerifier {
  private client=new OAuth2Client();
  constructor(private audience:string,private email:string) {}
  async verify(token:string) {
    try {
      const ticket=await this.client.verifyIdToken({idToken:token,audience:this.audience}); const p=ticket.getPayload();
      invariant(p?.email===this.email && p.email_verified===true && ['accounts.google.com','https://accounts.google.com'].includes(p.iss),401,'INVALID_PUSH_IDENTITY');
    } catch {throw new AppError(401,'INVALID_PUSH_IDENTITY');}
  }
}
