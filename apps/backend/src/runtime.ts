import pino from 'pino';
import {config} from './config.js';
import {createPool} from './db.js';
import {Vault} from './crypto.js';
import {Queue} from './queue.js';
import {Auth} from './auth.js';
import {GooglePlay,PubSubVerifier} from './google-play.js';
import {Commerce} from './commerce.js';
import {CloudSaves} from './cloud-saves.js';
import {Notifications} from './notifications.js';
export function runtime() {
  const env=config(),pool=createPool(env.DATABASE_URL,env.DB_TLS,env.DB_CA_FILE);
  const logger=pino();const log=(value:object)=>logger.info(value);
  pool.on('error',()=>logger.error({event:'database_connection_error'}));
  const vault=new Vault(JSON.parse(env.TOKEN_ENCRYPTION_KEYS),env.TOKEN_ENCRYPTION_KEY_ID);
  const queue=new Queue(pool,vault);
  const auth=new Auth(pool,queue,{secret:Buffer.from(env.AUTH_JWT_SECRET,'base64'),issuer:env.AUTH_ISSUER,audience:env.AUTH_AUDIENCE,publicUrl:env.PUBLIC_BASE_URL.replace(/\/$/,'')});
  const commerce=new Commerce(pool,new GooglePlay(),queue),saves=new CloudSaves(pool,commerce),notifications=new Notifications(commerce,queue);
  const push=new PubSubVerifier(env.PUBSUB_AUDIENCE,env.PUBSUB_SERVICE_ACCOUNT_EMAIL);
  return {env,pool,queue,auth,commerce,saves,notifications,verifyPush:(token:string)=>push.verify(token),log};
}
