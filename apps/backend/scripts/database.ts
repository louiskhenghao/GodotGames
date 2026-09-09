import {createPool} from '../src/db.js';
export function scriptPool(migration=false) {
  const url=(migration?process.env.MIGRATIONS_DATABASE_URL:undefined)??process.env.DATABASE_URL;
  if (!url) throw new Error('Set DATABASE_URL (and MIGRATIONS_DATABASE_URL for migrations)');
  return createPool(url,process.env.DB_TLS!=='false',process.env.DB_CA_FILE);
}
