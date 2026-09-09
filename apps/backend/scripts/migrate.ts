import {scriptPool} from './database.js';
import {migrate} from './migrations.js';
const pool=scriptPool(true);
try {await migrate(pool);} finally {await pool.end();}
