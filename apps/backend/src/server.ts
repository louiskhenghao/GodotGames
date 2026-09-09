import {createApp} from './app.js';
import {runtime} from './runtime.js';
const r=runtime();
const app=createApp({...r,origins:r.env.CORS_ORIGINS.split(',').map(v=>v.trim()).filter(Boolean),trustProxy:r.env.TRUST_PROXY_HOPS});
const server=app.listen(r.env.PORT,()=>r.log({event:'api_listening',port:r.env.PORT}));
server.requestTimeout=120000;server.headersTimeout=15000;
let closing=false;
for (const signal of ['SIGINT','SIGTERM'] as const) process.on(signal,()=>{
  if (closing) return;closing=true;
  server.close(()=>{void r.pool.end().then(()=>process.exit(0));});
  setTimeout(()=>process.exit(1),30000).unref();
});
