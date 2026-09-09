import type {RequestHandler} from 'express';
import {hash} from './crypto.js';
import type {Pool} from './db.js';
export function rateLimit(pool:Pool,namespace:string,limit:number,seconds:number,key:(req:Parameters<RequestHandler>[0],res:Parameters<RequestHandler>[1])=>string):RequestHandler {
  return async (req,res,next)=>{
    try {
      const {rows}=await pool.query<{count:number}>(`insert into backend.rate_limits(key,count,expires_at) values($1,1,now()+$2*interval '1 second')
        on conflict(key) do update set count=case when backend.rate_limits.expires_at<now() then 1 else backend.rate_limits.count+1 end,
          expires_at=case when backend.rate_limits.expires_at<now() then excluded.expires_at else backend.rate_limits.expires_at end returning count`,[namespace+':'+hash(key(req,res)),seconds]);
      if (rows[0]!.count>limit) {res.setHeader('Retry-After',String(seconds));res.status(429).json({error:'RATE_LIMITED'});return;}
      next();
    } catch(error) {next(error);}
  };
}
