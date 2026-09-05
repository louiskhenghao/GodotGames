class_name RushSkillGrowth
extends RefCounted
const MAX_LEVEL:=10
static func level(store:CoreSaveStore,id:String) -> int:return clampi(int(store.data.progress.get("skill_levels",{}).get(id,1)),1,MAX_LEVEL)
static func cost(rank:int) -> int:return 100+rank*70+rank*rank*12
static func buy(store:CoreSaveStore,id:String) -> bool:
 if RushRoster.move(id).id!=id or not RushRoster.owned(store,"move",id):return false
 var rank:=level(store,id)
 if rank>=MAX_LEVEL or store.data.coins<cost(rank):return false
 var next:=store.data.duplicate(true)
 next.coins-=cost(rank)
 if not next.progress.has("skill_levels"):next.progress.skill_levels={}
 next.progress.skill_levels[id]=rank+1
 RushAchievements.evaluate(next)
 return store.commit(next)
static func stats(rank:int) -> Dictionary:
 rank=clampi(rank,1,MAX_LEVEL)
 return {"damage":1+(rank-1)*.12,"radius":1+(rank-1)*.035,"cooldown":1-(rank-1)*.015,"stage":2 if rank>=10 else (1 if rank>=5 else 0)}
static func tint(id:String,rank:int,secondary:bool=false) -> Color:
 var original:Color=RushRoster.visual(id).color
 if rank<5:return original
 return original.lerp(Color("ffa6eb") if secondary else Color("b2f7ff"),.65 if rank>=10 else .3)
