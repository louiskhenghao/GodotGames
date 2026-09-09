import {randomUUID} from 'node:crypto';
import type {DB,Pool} from './db.js';
import {tx} from './db.js';
import {Vault} from './crypto.js';
import {safeCode} from './errors.js';
export type JobKind='notification'|'finalize'|'sync'|'reconcile'|'email';
export interface Job {id:string; kind:JobKind; payload_cipher:string; attempts:number; lease_id:string;}
export class Queue {
  constructor(readonly pool:Pool,readonly vault:Vault) {}
  async add(db:DB,kind:JobKind,key:string,payload:unknown) {
    await db.query('insert into backend.jobs(kind,dedupe_key,payload_cipher) values($1,$2,$3) on conflict(dedupe_key) do nothing',[kind,key,this.vault.seal(JSON.stringify(payload))]);
  }
  async claim():Promise<Job|undefined> {
    return tx(this.pool,async db => {
      const result=await db.query<Job>(`update backend.jobs set status='running',attempts=attempts+1,lease_id=$1,lease_until=now()+interval '5 minutes'
        where id=(select id from backend.jobs where (status='ready' and available_at<=now()) or (status='running' and lease_until<now())
          order by available_at,id for update skip locked limit 1) returning *`,[randomUUID()]);
      return result.rows[0];
    });
  }
  payload<T>(job:Job):T {return JSON.parse(this.vault.open(job.payload_cipher)) as T;}
  async finish(job:Job) {
    await this.pool.query(`update backend.jobs set status='done',completed_at=now(),lease_until=null where id=$1 and lease_id=$2`,[job.id,job.lease_id]);
  }
  async fail(job:Job,error:unknown) {
    const delay=Math.min(3600,2**Math.min(job.attempts,12)*5);
    await this.pool.query(`update backend.jobs set status=$3,error_code=$4,available_at=now()+$5*interval '1 second',lease_until=null
      where id=$1 and lease_id=$2`,[job.id,job.lease_id,job.attempts>=20?'dead':'ready',safeCode(error),delay]);
  }
}
