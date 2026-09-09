import {scriptPool} from './database.js';
import {operationalStatus} from '../src/worker.js';
const pool=scriptPool();
try {
 const status=await operationalStatus(pool);console.log(JSON.stringify(status,null,2));
 if (status.overdueFinalizations>0 || status.jobs.some(j=>j.status==='dead') || status.games.some(g=>!g.last_reconciled_at || Date.now()-new Date(g.last_reconciled_at).getTime()>86400000)) process.exitCode=1;
} finally {await pool.end();}
