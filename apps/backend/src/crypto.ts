import {createHash, randomBytes, createCipheriv, createDecipheriv, scrypt as scryptCallback, timingSafeEqual} from 'node:crypto';
const scrypt=(password:string,salt:string) => new Promise<Buffer>((resolve,reject) => {
  scryptCallback(password,salt,64,{N:32768,r:8,p:3,maxmem:64*1024*1024},(error,key)=>error?reject(error):resolve(key));
});
export const randomToken=() => randomBytes(32).toString('base64url');
export const hash=(value: string) => createHash('sha256').update(value).digest('hex');
export async function passwordHash(password: string) {
  const salt=randomBytes(16).toString('hex');
  const key=await scrypt(password,salt);
  return `scrypt-v1:${salt}:${key.toString('hex')}`;
}
export async function passwordMatches(password: string, encoded: string) {
  const [,salt,key]=encoded.split(':');
  if (!salt || !key) return false;
  const actual=await scrypt(password,salt);
  const expected=Buffer.from(key,'hex');
  return actual.length===expected.length && timingSafeEqual(actual,expected);
}
export class Vault {
  private keys: Map<string,Buffer>;
  constructor(keys: Record<string,string>, private current: string) {
    this.keys=new Map(Object.entries(keys).map(([id,key]) => [id,Buffer.from(key,'base64')]));
    if (!this.keys.has(current) || [...this.keys].some(([id,k]) => !/^[a-z0-9_-]+$/i.test(id) || k.length!==32)) throw new Error('Invalid encryption keyring');
  }
  seal(value: string) {
    const iv=randomBytes(12); const cipher=createCipheriv('aes-256-gcm',this.keys.get(this.current)!,iv);
    cipher.setAAD(Buffer.from(this.current));
    const encrypted=Buffer.concat([cipher.update(value,'utf8'),cipher.final()]);
    return [this.current,iv.toString('base64url'),cipher.getAuthTag().toString('base64url'),encrypted.toString('base64url')].join('.');
  }
  open(value: string) {
    const [id,iv,tag,data,...extra]=value.split('.'); const key=this.keys.get(id!);
    if (!key || !iv || !tag || !data || extra.length) throw new Error('Invalid encrypted value');
    const decipher=createDecipheriv('aes-256-gcm',key,Buffer.from(iv,'base64url'));
    decipher.setAAD(Buffer.from(id!)); decipher.setAuthTag(Buffer.from(tag,'base64url'));
    return Buffer.concat([decipher.update(Buffer.from(data,'base64url')),decipher.final()]).toString('utf8');
  }
}
