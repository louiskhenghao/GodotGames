import {scriptPool} from './database.js';
const id=process.argv[2];if (!id || !/^\d+$/.test(id)) throw new Error('Usage: retry-job.ts <dead-job-id>');
const pool=scriptPool();
try {
 const result=await pool.query("update backend.jobs set status='ready',attempts=0,error_code=null,available_at=now(),lease_id=null,lease_until=null where id=$1 and status='dead' returning id",[id]);
 console.log(result.rowCount?'Job requeued':'No dead job with that ID');
} finally {await pool.end();}
