import {readdir,readFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {tx,lock,type Pool} from '../src/db.js';
export async function migrate(pool:Pool) {
  const directory=fileURLToPath(new URL('../migrations/',import.meta.url));
  await tx(pool,async db=>{
    await lock(db,'zxlabs-backend-migrations');
    await db.query('create schema if not exists backend');
    await db.query('revoke all on schema backend from public');
    await db.query('create table if not exists backend.schema_migrations(name text primary key,sha256 text not null,applied_at timestamptz not null default now())');
    for (const name of (await readdir(directory)).filter(n=>n.endsWith('.sql')).sort()) {
      const sql=await readFile(directory+'/'+name,'utf8'),checksum=createHash('sha256').update(sql).digest('hex');
      const old=(await db.query<{sha256:string}>('select sha256 from backend.schema_migrations where name=$1',[name])).rows[0];
      if (old) {if (old.sha256!==checksum) throw new Error('Applied migration changed: '+name);continue;}
      await db.query(sql);
      await db.query('insert into backend.schema_migrations(name,sha256) values($1,$2)',[name,checksum]);
      console.log('Applied migration:',name);
    }
  });
}
