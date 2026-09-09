import {z} from 'zod';
const bool=z.enum(['true','false']).transform(v=>v==='true');
const schema=z.object({
  NODE_ENV:z.enum(['development','test','production']).default('development'), PORT:z.coerce.number().int().min(1).max(65535).default(3000),
  DATABASE_URL:z.url(), DB_TLS:bool.default(true), DB_CA_FILE:z.string().optional(),
  PUBLIC_BASE_URL:z.url(), AUTH_ISSUER:z.string().min(1).default('zxlabs-games'),AUTH_AUDIENCE:z.string().min(1).default('zxlabs-games-api'),
  AUTH_JWT_SECRET:z.string().min(44), TOKEN_ENCRYPTION_KEYS:z.string(),TOKEN_ENCRYPTION_KEY_ID:z.string().default('v1'),
  PUBSUB_AUDIENCE:z.url(),PUBSUB_SERVICE_ACCOUNT_EMAIL:z.email(),
  CORS_ORIGINS:z.string().default(''), TRUST_PROXY_HOPS:z.coerce.number().int().min(0).max(5).default(0),
  SMTP_HOST:z.string().min(1),SMTP_PORT:z.coerce.number().int().default(587),SMTP_SECURE:bool.default(false),
  SMTP_USER:z.string().optional(),SMTP_PASSWORD:z.string().optional(),MAIL_FROM:z.string().min(1),
  WORKER_POLL_MS:z.coerce.number().int().min(100).default(1000)
});
export function config(env:NodeJS.ProcessEnv=process.env) {
  const result=schema.parse(env);
  if (Buffer.from(result.AUTH_JWT_SECRET,'base64').length<32) throw new Error('AUTH_JWT_SECRET must contain at least 32 random bytes');
  if (result.NODE_ENV==='production' && (!result.DB_TLS || !result.PUBLIC_BASE_URL.startsWith('https://') || !result.PUBSUB_AUDIENCE.startsWith('https://'))) throw new Error('Production requires verified DB TLS and HTTPS public URLs');
  return result;
}
export type Config=ReturnType<typeof config>;
