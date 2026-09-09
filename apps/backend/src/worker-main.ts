import nodemailer from 'nodemailer';
import {runtime} from './runtime.js';
import {Worker,mailSender} from './worker.js';
const r=runtime();
const transport=nodemailer.createTransport({host:r.env.SMTP_HOST,port:r.env.SMTP_PORT,secure:r.env.SMTP_SECURE,
  requireTLS:r.env.NODE_ENV==='production' && !r.env.SMTP_SECURE,
  connectionTimeout:10000,greetingTimeout:10000,socketTimeout:20000,
  ...(r.env.SMTP_USER?{auth:{user:r.env.SMTP_USER,pass:r.env.SMTP_PASSWORD}}:{})});
const controller=new AbortController();
for (const signal of ['SIGINT','SIGTERM'] as const) process.on(signal,()=>controller.abort());
const worker=new Worker(r.queue,r.commerce,r.notifications,mailSender(transport,r.env.MAIL_FROM),r.log);
await worker.run(controller.signal,r.env.WORKER_POLL_MS);
transport.close();await r.pool.end();
