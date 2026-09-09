import { readFileSync } from 'node:fs';
import pg from 'pg';
export type DB = Pick<pg.PoolClient, 'query'>;
export type Pool = pg.Pool;
export function createPool(url: string, tls: boolean, caFile?: string): Pool {
  const parsed = new URL(url);
  // pg connection-string SSL options otherwise override the explicit TLS policy.
  for (const key of ['sslmode','sslcert','sslkey','sslrootcert']) parsed.searchParams.delete(key);
  return new pg.Pool({connectionString: parsed.toString(), max: 10,
    connectionTimeoutMillis: 5000, idleTimeoutMillis: 30000,
    statement_timeout: 30000, idle_in_transaction_session_timeout: 45000,
    ssl: tls ? {rejectUnauthorized: true, ...(caFile ? {ca:readFileSync(caFile,'utf8')} : {})} : false});
}
export async function tx<T>(pool: Pool, fn: (db: DB) => Promise<T>): Promise<T> {
  const db=await pool.connect();
  try {await db.query('begin'); const result=await fn(db); await db.query('commit'); return result;}
  catch(error) {await db.query('rollback'); throw error;} finally {db.release();}
}
export async function lock(db: DB, key: string) {
  await db.query('select pg_advisory_xact_lock(hashtextextended($1,0))',[key]);
}
