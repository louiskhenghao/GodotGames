import express,{type RequestHandler,type ErrorRequestHandler} from 'express';
import helmet from 'helmet';
import {randomUUID} from 'node:crypto';
import {z,ZodError} from 'zod';
import type {Auth,Identity} from './auth.js';
import type {Commerce} from './commerce.js';
import type {CloudSaves} from './cloud-saves.js';
import type {Notifications} from './notifications.js';
import {AppError,invariant,safeCode} from './errors.js';
import {rateLimit} from './rate-limit.js';
export interface Dependencies {auth:Auth;commerce:Commerce;saves:CloudSaves;notifications:Notifications;verifyPush:(token:string)=>Promise<void>;origins:string[];trustProxy:number; log:(value:object)=>void;}
const email=z.email().max(254).transform(v=>v.trim().toLowerCase());
const password=z.string().min(12).max(128);
const credentials=z.object({email,password}).strict();
const token=z.string().min(32).max(4096);
const cursor=z.string().regex(/^(0|[1-9][0-9]{0,17})$/);
const gameId=z.string().regex(/^[a-z][a-z0-9_-]{1,47}$/);
function bearer(value:string|undefined) {invariant(typeof value==='string' && value.startsWith('Bearer ') && value.length<8192,401,'BEARER_TOKEN_REQUIRED');return value.slice(7);}
export function createApp(d:Dependencies) {
  const app=express();app.disable('x-powered-by');app.set('trust proxy',d.trustProxy);
  app.use(helmet());
  app.use((req,res,next)=>{
    const requestId=randomUUID();res.locals.requestId=requestId;res.setHeader('X-Request-Id',requestId);res.setHeader('Cache-Control','no-store');
    res.on('finish',()=>d.log({requestId,method:req.method,path:req.path,status:res.statusCode})); // No tokens, email, headers, body or query strings.
    const origin=req.headers.origin;
    if (origin && d.origins.includes(origin)) {res.setHeader('Access-Control-Allow-Origin',origin);res.setHeader('Vary','Origin');res.setHeader('Access-Control-Allow-Headers','Authorization, Content-Type');res.setHeader('Access-Control-Allow-Methods','GET, POST, PUT, OPTIONS');}
    if (req.method==='OPTIONS') {res.sendStatus(origin && !d.origins.includes(origin)?403:204);return;}next();
  });
  app.use(express.json({limit:'520kb',strict:true}));app.use(express.urlencoded({extended:false,limit:'8kb'}));
  app.get('/health/live',(_req,res)=>res.json({status:'ok'}));
  app.get('/health/ready',async(_req,res)=>{await d.auth.pool.query('select 1 from backend.games limit 1');res.json({status:'ready'});});
  // Validated service identity, expected subscription and package mapping; never a shared query secret.
  app.post('/webhooks/google-play',async(req,res)=>{
    await d.verifyPush(bearer(req.headers.authorization));await d.notifications.accept(req.body);res.sendStatus(204);
  });
  const ip=(req:express.Request)=>req.ip??'unknown';
  const loginLimit=rateLimit(d.auth.pool,'auth-ip',30,900,ip);
  const accountLimit=rateLimit(d.auth.pool,'auth-email',10,900,req=>String(req.body?.email??'').trim().toLowerCase());
  app.use('/v1/auth',loginLimit);
  app.post('/v1/auth/register',accountLimit,async(req,res)=>{const b=credentials.parse(req.body);await d.auth.register(b.email,b.password);res.status(202).json({message:'If this address is eligible, a verification email will be sent.'});});
  app.post('/v1/auth/login',accountLimit,async(req,res)=>{const b=credentials.parse(req.body);res.json(await d.auth.login(b.email,b.password));});
  app.post('/v1/auth/refresh',async(req,res)=>{const b=z.object({refreshToken:token}).strict().parse(req.body);res.json(await d.auth.refresh(b.refreshToken));});
  for (const [path,purpose] of [['resend-verification','verify'],['forgot-password','reset']] as const) {
    app.post('/v1/auth/'+path,accountLimit,async(req,res)=>{const b=z.object({email}).strict().parse(req.body);await d.auth.requestEmail(b.email,purpose);res.status(202).json({message:'If this address is eligible, an email will be sent.'});});
  }
  app.post('/v1/auth/verify-email',async(req,res)=>{const b=z.object({token}).strict().parse(req.body);await d.auth.useEmailToken(b.token,'verify');res.json({verified:true});});
  app.post('/v1/auth/reset-password',async(req,res)=>{const b=z.object({token,password}).strict().parse(req.body);await d.auth.useEmailToken(b.token,'reset',b.password);res.json({message:'Password changed. Sign in again.'});});
  // Email scanners may GET this page without consuming the token. Only explicit POST applies it.
  app.get('/auth/action',(req,res)=>{
    const b=z.object({purpose:z.enum(['verify','reset']),token:z.string().regex(/^[A-Za-z0-9_-]{43}$/)}).parse(req.query);
    const reset=b.purpose==='reset';
    res.type('html').send(`<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>ZX Labs account</title><body><main><h1>${reset?'Reset password':'Verify email'}</h1><form method="post" action="/v1/auth/${reset?'reset-password':'verify-email'}"><input type="hidden" name="token" value="${b.token}">${reset?'<label>New password (12–128 characters) <input type="password" name="password" minlength="12" maxlength="128" autocomplete="new-password" required></label>':''}<button type="submit">${reset?'Set password':'Confirm email'}</button></form></main></body></html>`);
  });
  const authenticate:RequestHandler=async(req,res,next)=>{try {res.locals.identity=await d.auth.authenticate(bearer(req.headers.authorization));next();} catch(error) {next(error);}};
  const who=(res:express.Response):Identity=>res.locals.identity;
  app.get('/v1/auth/me',authenticate,(_req,res)=>res.json({userId:who(res).userId,emailVerified:who(res).verified}));
  app.post('/v1/auth/logout',authenticate,async(_req,res)=>{await d.auth.logout(who(res));res.sendStatus(204);});
  app.post('/v1/auth/logout-all',authenticate,async(_req,res)=>{await d.auth.logout(who(res),true);res.sendStatus(204);});
  app.use('/v1/games/:gameId',authenticate,(req,res,next)=>{
    try {gameId.parse(req.params.gameId);invariant(who(res).verified,403,'EMAIL_VERIFICATION_REQUIRED');next();} catch(error) {next(error);}
  },rateLimit(d.auth.pool,'game-api',120,60,(_req,res)=>who(res).userId));
  const game=(req:express.Request)=>gameId.parse(req.params.gameId);
  app.get('/v1/games/:gameId/billing-context',async(req,res)=>res.json(await d.commerce.context(game(req),who(res).userId)));
  app.post('/v1/games/:gameId/purchases/verify',async(req,res)=>{
    const b=z.object({purchaseToken:token,productId:z.string().min(1).max(256)}).strict().parse(req.body);
    const purchase=await d.commerce.sync(game(req),b.purchaseToken,{productId:b.productId,userId:who(res).userId});
    res.json({purchase,inventory:await d.commerce.inventory(game(req),who(res).userId)});
  });
  app.post('/v1/games/:gameId/purchases/restore',async(req,res)=>{
    const b=z.object({purchaseTokens:z.array(token).max(20)}).strict().parse(req.body);res.json(await d.commerce.restore(game(req),who(res).userId,b.purchaseTokens));
  });
  app.get('/v1/games/:gameId/inventory',async(req,res)=>res.json(await d.commerce.inventory(game(req),who(res).userId)));
  app.get('/v1/games/:gameId/ledger',async(req,res)=>res.json(await d.commerce.ledger(game(req),who(res).userId,cursor.parse(req.query.after??'0'))));
  app.get('/v1/games/:gameId/save',async(req,res)=>res.json(await d.saves.get(game(req),who(res).userId)));
  app.put('/v1/games/:gameId/save',async(req,res)=>{
    const b=z.object({expectedRevision:cursor,schemaVersion:z.number().int().positive().max(10000),purchaseCursor:cursor,payload:z.record(z.string(),z.unknown())}).strict().parse(req.body);
    res.json(await d.saves.put(game(req),who(res).userId,b));
  });
  app.use((_req,res)=>res.status(404).json({error:'NOT_FOUND'}));
  const errors:ErrorRequestHandler=(error,_req,res,_next)=>{
    let status=500,code=safeCode(error);
    if (error instanceof AppError) status=error.status;
    else if (error instanceof ZodError || error?.type==='entity.parse.failed') {status=400;code='INVALID_REQUEST';}
    else if (error?.type==='entity.too.large') {status=413;code='REQUEST_TOO_LARGE';}
    d.log({requestId:res.locals.requestId,error:code,status});
    res.status(status).json({error:code,requestId:res.locals.requestId});
  };
  app.use(errors);return app;
}
