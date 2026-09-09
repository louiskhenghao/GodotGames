import {randomUUID} from 'node:crypto';
import {SignJWT,jwtVerify} from 'jose';
import {hash,randomToken,passwordHash,passwordMatches} from './crypto.js';
import {tx,lock,type DB,type Pool} from './db.js';
import {AppError,invariant} from './errors.js';
import {Queue} from './queue.js';
export interface Identity {userId:string; sessionId:string; verified:boolean;}
export interface AuthSettings {secret:Uint8Array; issuer:string; audience:string; publicUrl:string;}
interface User {id:string;email:string;password_hash:string;email_verified_at:Date|null;}
interface Session {id:string;user_id:string;family_id:string;used_at:Date|null;revoked_at:Date|null;expires_at:Date;}
export class Auth {
  constructor(readonly pool:Pool,readonly queue:Queue,readonly settings:AuthSettings) {}
  async register(email:string,password:string) {
    const encoded=await passwordHash(password);
    await tx(this.pool,async db=>{
      await lock(db,'email:'+email);
      const old=await db.query<User>('select * from backend.users where email=$1',[email]);
      if (old.rows[0]) return; // Never overwrite a password or reveal registration status.
      const id=randomUUID();
      await db.query('insert into backend.users(id,email,password_hash) values($1,$2,$3)',[id,email,encoded]);
      await this.mailToken(db,id,email,'verify');
    });
  }
  private async mailToken(db:DB,userId:string,email:string,purpose:'verify'|'reset') {
    const token=randomToken();
    await db.query(`insert into backend.auth_tokens(token_hash,user_id,purpose,expires_at) values($1,$2,$3,now()+$4*interval '1 minute')`,[hash(token),userId,purpose,purpose==='verify'?1440:30]);
    await this.queue.add(db,'email',`auth:${hash(token)}`,{to:email,purpose,url:`${this.settings.publicUrl}/auth/action?purpose=${purpose}&token=${token}`});
  }
  async requestEmail(email:string,purpose:'verify'|'reset') {
    await tx(this.pool,async db=>{
      await lock(db,'email:'+email);
      const {rows}=await db.query<User>('select * from backend.users where email=$1',[email]);
      const user=rows[0];
      if (user && (purpose==='reset' || !user.email_verified_at)) await this.mailToken(db,user.id,email,purpose);
    });
  }
  private async tokens(db:DB,userId:string,familyId:string) {
    const refreshToken=randomToken(), id=randomUUID();
    await db.query(`insert into backend.sessions(id,user_id,family_id,token_hash,expires_at) values($1,$2,$3,$4,now()+interval '30 days')`,[id,userId,familyId,hash(refreshToken)]);
    const accessToken=await new SignJWT({sid:id}).setProtectedHeader({alg:'HS256',typ:'JWT'})
      .setSubject(userId).setIssuer(this.settings.issuer).setAudience(this.settings.audience)
      .setIssuedAt().setExpirationTime('15m').sign(this.settings.secret);
    return {accessToken,refreshToken,tokenType:'Bearer',expiresIn:900,userId};
  }
  async login(email:string,password:string) {
    const {rows}=await this.pool.query<User>('select * from backend.users where email=$1',[email]);
    const user=rows[0];
    const valid=await passwordMatches(password,user?.password_hash ?? `scrypt-v1:${'0'.repeat(32)}:${'0'.repeat(128)}`);
    invariant(user && valid,401,'INVALID_CREDENTIALS');
    return tx(this.pool,async db=>{
      // Serialize against password reset to avoid issuing a session from an old hash.
      await lock(db,'user:'+user.id);
      const current=await db.query<User>('select * from backend.users where id=$1',[user.id]);
      invariant(current.rows[0]?.password_hash===user.password_hash,401,'INVALID_CREDENTIALS');
      return this.tokens(db,user.id,randomUUID());
    });
  }
  async refresh(token:string) {
    const lookup=await this.pool.query<Session>('select * from backend.sessions where token_hash=$1',[hash(token)]);
    const found=lookup.rows[0];invariant(found,401,'INVALID_REFRESH_TOKEN');
    const outcome=await tx(this.pool,async db=>{
      await lock(db,'user:'+found.user_id);
      const {rows}=await db.query<Session>('select * from backend.sessions where id=$1 for update',[found.id]);
      const session=rows[0]!;
      if (session.used_at) {
        await db.query('update backend.sessions set revoked_at=coalesce(revoked_at,now()) where family_id=$1',[session.family_id]);
        return null; // Commit revocation before returning the error.
      }
      if (session.revoked_at || session.expires_at<=new Date()) return null;
      await db.query('update backend.sessions set used_at=now() where id=$1',[session.id]);
      return this.tokens(db,session.user_id,session.family_id);
    });
    invariant(outcome,401,'INVALID_REFRESH_TOKEN');return outcome;
  }
  async authenticate(bearer:string):Promise<Identity> {
    let payload;
    try {({payload}=await jwtVerify(bearer,this.settings.secret,{algorithms:['HS256'],issuer:this.settings.issuer,audience:this.settings.audience}));}
    catch {throw new AppError(401,'INVALID_ACCESS_TOKEN');}
    invariant(typeof payload.sub==='string' && typeof payload.sid==='string' && /^[0-9a-f-]{36}$/i.test(payload.sid) && /^[0-9a-f-]{36}$/i.test(payload.sub),401,'INVALID_ACCESS_TOKEN');
    const {rows}=await this.pool.query(`select u.email_verified_at from backend.sessions s join backend.users u on u.id=s.user_id
      where s.id=$1 and s.user_id=$2 and s.revoked_at is null and s.expires_at>now()`,[payload.sid,payload.sub]);
    invariant(rows[0],401,'SESSION_REVOKED');
    return {userId:payload.sub,sessionId:payload.sid,verified:!!rows[0].email_verified_at};
  }
  async logout(identity:Identity,all=false) {
    await tx(this.pool,async db=>{
      await lock(db,'user:'+identity.userId);
      if (all) await db.query('update backend.sessions set revoked_at=coalesce(revoked_at,now()) where user_id=$1',[identity.userId]);
      else await db.query(`update backend.sessions set revoked_at=coalesce(revoked_at,now()) where family_id=(select family_id from backend.sessions where id=$1 and user_id=$2)`,[identity.sessionId,identity.userId]);
    });
  }
  async useEmailToken(token:string,purpose:'verify'|'reset',password?:string) {
    const encoded=purpose==='reset'?await passwordHash(password!):null;
    // Take the user lock first everywhere to avoid lock-order inversions with refresh/login.
    const initial=await this.pool.query<{user_id:string}>('select user_id from backend.auth_tokens where token_hash=$1 and purpose=$2',[hash(token),purpose]);
    invariant(initial.rows[0],400,'INVALID_EMAIL_TOKEN');
    await tx(this.pool,async db=>{
      const userId=initial.rows[0]!.user_id;await lock(db,'user:'+userId);
      const {rows}=await db.query(`update backend.auth_tokens set used_at=now() where token_hash=$1 and purpose=$2 and used_at is null and expires_at>now() returning user_id`,[hash(token),purpose]);
      invariant(rows[0],400,'INVALID_EMAIL_TOKEN');
      if (purpose==='reset') {
        await db.query('update backend.users set password_hash=$2,email_verified_at=coalesce(email_verified_at,now()) where id=$1',[userId,encoded]);
        await db.query('update backend.sessions set revoked_at=coalesce(revoked_at,now()) where user_id=$1',[userId]);
        await db.query(`update backend.auth_tokens set used_at=now() where user_id=$1 and used_at is null`,[userId]);
      } else await db.query('update backend.users set email_verified_at=coalesce(email_verified_at,now()) where id=$1',[userId]);
    });
  }
}
