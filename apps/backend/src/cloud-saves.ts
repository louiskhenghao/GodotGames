import {type Pool,tx,lock} from './db.js';
import {AppError,invariant} from './errors.js';
import {Commerce} from './commerce.js';
export interface SaveInput {expectedRevision:string; schemaVersion:number;purchaseCursor:string;payload:Record<string,unknown>;}
interface SaveRow {revision:string;schema_version:number;purchase_cursor:string;payload:Record<string,unknown>;updated_at:Date;}
const output=(row:SaveRow|undefined) => row ? {revision:row.revision,schemaVersion:row.schema_version,purchaseCursor:row.purchase_cursor,payload:row.payload,updatedAt:row.updated_at} : null;
export class CloudSaves {
  constructor(readonly pool:Pool,readonly commerce:Commerce) {}
  async get(gameId:string,userId:string) {
    await this.commerce.game(gameId);
    const {rows}=await this.pool.query<SaveRow>('select * from backend.cloud_saves where game_id=$1 and user_id=$2',[gameId,userId]);
    return {save:output(rows[0])};
  }
  async put(gameId:string,userId:string,input:SaveInput) {
    invariant(Buffer.byteLength(JSON.stringify(input.payload))<=500_000,413,'SAVE_TOO_LARGE');
    // Game progress is client-authored. It never writes users, purchases, grants or entitlements.
    await this.commerce.context(gameId,userId);
    return tx(this.pool,async db=>{
      await lock(db,`account:${gameId}:${userId}`);
      const current=(await db.query<SaveRow>('select * from backend.cloud_saves where game_id=$1 and user_id=$2 for update',[gameId,userId])).rows[0];
      if ((current?.revision??'0')!==input.expectedRevision) throw new AppError(409,'SAVE_REVISION_CONFLICT');
      const cursor=(await db.query<{cursor:string}>('select coalesce(max(sequence),0)::text as cursor from backend.ledger where game_id=$1 and user_id=$2',[gameId,userId])).rows[0]!.cursor;
      // A new grant/refund must be applied before publishing the next synchronized save.
      invariant(cursor===input.purchaseCursor,409,'COMMERCE_CHANGED');
      invariant(!current || input.schemaVersion>=current.schema_version,409,'SAVE_SCHEMA_DOWNGRADE');
      if (current) await db.query(`insert into backend.cloud_save_history(game_id,user_id,revision,schema_version,purchase_cursor,payload)
        values($1,$2,$3,$4,$5,$6)`,[gameId,userId,current.revision,current.schema_version,current.purchase_cursor,current.payload]);
      const {rows}=await db.query<SaveRow>(`insert into backend.cloud_saves(game_id,user_id,revision,schema_version,purchase_cursor,payload)
        values($1,$2,$3::bigint+1,$4,$5,$6) on conflict(game_id,user_id) do update set revision=excluded.revision,
        schema_version=excluded.schema_version,purchase_cursor=excluded.purchase_cursor,payload=excluded.payload,updated_at=now() returning *`,
        [gameId,userId,input.expectedRevision,input.schemaVersion,input.purchaseCursor,input.payload]);
      await db.query('delete from backend.cloud_save_history where game_id=$1 and user_id=$2 and revision<$3::bigint-9',[gameId,userId,rows[0]!.revision]);
      return {save:output(rows[0])};
    });
  }
}
