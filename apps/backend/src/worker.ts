import {setTimeout as sleep} from 'node:timers/promises';
import type {Transporter} from 'nodemailer';
import {Queue,type Job} from './queue.js';
import {Commerce} from './commerce.js';
import {Notifications,type PlayEvent} from './notifications.js';
import {tx,type Pool} from './db.js';
import {invariant,safeCode} from './errors.js';
export interface Mail {to:string;purpose:'verify'|'reset';url:string;}
export class Worker {
  constructor(readonly queue:Queue,readonly commerce:Commerce,readonly notifications:Notifications,readonly sendMail:(mail:Mail)=>Promise<void>,readonly log:(value:object)=>void) {}
  async dispatch(job:Job) {
    switch(job.kind) {
      case 'email':await this.sendMail(this.queue.payload<Mail>(job));return;
      case 'finalize':await this.commerce.finalize(this.queue.payload<{purchaseId:string}>(job).purchaseId);return;
      case 'sync': {const p=this.queue.payload<{gameId:string;token:string;fullRefund?:boolean}>(job);await this.commerce.sync(p.gameId,p.token,{fullRefund:p.fullRefund});return;}
      case 'notification': {const p=this.queue.payload<{gameId:string;event:PlayEvent}>(job);await this.notifications.process(p.gameId,p.event);return;}
      case 'reconcile':await this.notifications.reconcile(this.queue.payload<{gameId:string}>(job).gameId);return;
    }
  }
  async once() {
    const job=await this.queue.claim();if (!job) return false;
    const heartbeat=setInterval(()=>{void this.queue.pool.query(`update backend.jobs set lease_until=now()+interval '5 minutes' where id=$1 and lease_id=$2 and status='running'`,[job.id,job.lease_id]).catch(()=>this.log({event:'lease_refresh_failed',jobId:job.id}));},60000);
    try {await this.dispatch(job);await this.queue.finish(job);this.log({event:'job_done',jobId:job.id,kind:job.kind});}
    catch(error) {await this.queue.fail(job,error);this.log({event:'job_failed',jobId:job.id,kind:job.kind,code:safeCode(error)});}
    finally {clearInterval(heartbeat);}
    return true;
  }
  async schedule() {
    const pool=this.queue.pool;
    const games=await pool.query<{id:string}>('select id from backend.games where enabled=true');
    for (const game of games.rows) await this.queue.add(pool,'reconcile',`reconcile:${game.id}:${Math.floor(Date.now()/21600000)}`,{gameId:game.id});
    await tx(pool,async db=>{
      const {rows}=await db.query<{id:string;game_id:string;token_cipher:string}>(`select id,game_id,token_cipher from backend.purchases
        where next_check_at<=now() and (state='PENDING' or (state='PURCHASED' and (finalized_at is null or kind='non_consumable')))
        order by next_check_at for update skip locked limit 100`);
      for (const p of rows) {
        await this.queue.add(db,'sync',`periodic:${p.id}:${Math.floor(Date.now()/300000)}`,{gameId:p.game_id,token:this.queue.vault.open(p.token_cipher)});
        await db.query("update backend.purchases set next_check_at=now()+interval '10 minutes' where id=$1",[p.id]);
      }
      await db.query("delete from backend.rate_limits where expires_at<now()-interval '1 day'");
      await db.query("delete from backend.auth_tokens where expires_at<now()-interval '7 days'");
      // Keep rotated refresh hashes until expiry so reuse detection remains possible.
      await db.query("delete from backend.sessions where expires_at<now()-interval '7 days'");
      await db.query("delete from backend.jobs where status='done' and kind='email' and completed_at<now()-interval '7 days'");
    });
  }
  async run(signal:AbortSignal,pollMs:number) {
    let nextSchedule=0;
    while (!signal.aborted) {
      try {
        if (Date.now()>=nextSchedule) {await this.schedule();nextSchedule=Date.now()+60000;}
        if (await this.once()) continue;
      } catch(error) {this.log({event:'worker_error',code:safeCode(error)});}
      try {await sleep(pollMs,undefined,{signal});} catch {break;}
    }
  }
}
export function mailSender(transport:Transporter,from:string) {
  return async(mail:Mail)=>{
    invariant(['verify','reset'].includes(mail.purpose),500,'INVALID_MAIL_JOB');
    const result=await transport.sendMail({from,to:mail.to,subject:mail.purpose==='verify'?'Verify your ZX Labs account':'Reset your ZX Labs password',
      text:`${mail.purpose==='verify'?'Verify your email address':'Choose a new password'}:\n\n${mail.url}\n\nIf you did not request this, ignore this email.`});
    invariant((result.accepted?.length??0)>0,503,'EMAIL_NOT_ACCEPTED');
  };
}
export async function operationalStatus(pool:Pool) {
  const jobs=await pool.query(`select kind,status,count(*)::int as count,min(created_at) as oldest from backend.jobs where status<>'done' group by kind,status`);
  const purchases=await pool.query(`select count(*)::int as count from backend.purchases where state='PURCHASED' and finalized_at is null and created_at<now()-interval '2 hours'`);
  const games=await pool.query('select id,last_reconciled_at from backend.games where enabled=true');
  return {jobs:jobs.rows,overdueFinalizations:purchases.rows[0].count,games:games.rows};
}
