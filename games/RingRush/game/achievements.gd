class_name RushAchievements
extends RefCounted
## Three durable stages per badge. Evaluation joins the caller's atomic save commit.
const TIERS:=["LOCKED","BRONZE","SILVER","GOLD"]
static func catalog() -> Array:
 var list:Array=[]
 for i in 4:_add(list,"ko_"+str(i),["FIRST BLOOD","HEAVY HITTER","CROWD BREAKER","KO LEGEND"][i],"COMBAT","total_kos",[100,500,2000,8000][i],"fist")
 for i in 3:_add(list,"combo_"+str(i),["IN THE FLOW","UNTOUCHABLE","COMBO KING"][i],"COMBAT","best_combo",[20,40,70][i],"bolt")
 for i in 2:_add(list,"boss_"+str(i),["GIANT SLAYER","BOSS HUNTER"][i],"COMBAT","boss_kos",[5,40][i],"crown")
 for mode in RushWaveDirector.MODES:
  if mode.id!="classic":_add(list,"clear_"+mode.id,mode.name,"VICTORIES","clears_"+mode.id,3,mode.icon)
 for i in 5:_add(list,"venue_"+str(i),["FIRST BELT","STREET JUSTICE","SKY HIGH","FORGED IN FIRE","DAWN MASTER"][i],"VICTORIES","wins_"+str(i),[3,5,8,10,15][i],"stairs")
 for i in 3:_add(list,"gym_"+str(i),["SHOW UP","GOLD STANDARD","MASTER CLASS"][i],"GROWTH","training_total",[30,100,220][i],"dumbbell")
 for i in 3:_add(list,"skill_"+str(i),["SHARPENED","AWAKENED","ASCENDED"][i],"GROWTH","highest_skill",[3,7,10][i],"nova")
 for i in 3:_add(list,"roster_"+str(i),["TAG TEAM","FIGHT CLUB","FULL ROSTER"][i],"GROWTH","fighters_owned",[3,7,9][i],"shield")
 for entry in [["quake","FAULT MAKER","quake"],["cyclone","STORM RIDER","cyclone"],["thunder","LIVE CURRENT","bolt"]]:_add(list,"cast_"+entry[0],entry[1],"STYLE","casts_"+entry[0],100,entry[2])
 _add(list,"ultimate","MAIN EVENT","STYLE","ultimates",40,"crown")
 _add(list,"dodge","SLIP ARTIST","STYLE","dodges",250,"dash")
 for i in 2:_add(list,"ranged_"+str(i),["LONG GAME","ARTILLERY ACE"][i],"COMBAT","ranged_kos",[100,600][i],"target")
 for i in 2:_add(list,"support_"+str(i),["GOOD COMPANY","SQUAD LEADER"][i],"STYLE","support_triggers",[30,150][i],"heart")
 _add(list,"counter","TURN THE TABLES","COMBAT","perfect_counters",10,"shield")
 _add(list,"breaker","GUARD CRUSHER","COMBAT","guard_breaks",20,"quake")
 return list
static func _add(list:Array,id:String,title:String,category:String,metric:String,target:int,icon:String) -> void:
 list.append({"id":id,"title":title,"category":category,"metric":metric,"target":target,"icon":icon,"bonus":["health","power","cooldown"][list.size()%3]})
static func metric(data:Dictionary,id:String) -> int:
 var p:Dictionary=data.progress
 if id=="training_total":
  var total:=0
  for entry in RushBalance.TRAINING:total+=clampi(int(p.get(entry.id,0)),0,30)
  return total
 if id=="highest_skill":
  var highest:=1
  for rank in p.get("skill_levels",{}).values():highest=maxi(highest,int(rank))
  return highest
 if id=="fighters_owned":
  var count:=1
  for entry in RushRoster.CHARACTERS:
   if entry.id!="atlas" and p.get("unlocks",{}).get("character:"+entry.id,false):count+=1
  return count
 if id=="wins":
  var count:=0
  for mode in RushWaveDirector.MODES:count+=int(p.get("clears_"+mode.id,0))
  return count
 if id=="hard_wins":return int(p.get("clears_hell",0))+int(p.get("clears_bossrush",0))+int(p.get("clears_onslaught50",0))
 return maxi(0,int(p.get(id,0)))
static func rank(data:Dictionary,id:String) -> int:
 return clampi(int(data.progress.get("badge_tiers",{}).get(id,1 if data.progress.get("badges",{}).get(id,false) else 0)),0,3)
static func target(entry:Dictionary,tier:int) -> int:
 tier=clampi(tier,1,3)
 match entry.metric:
  "highest_skill":return mini(10,entry.target+tier-1)
  "fighters_owned":return mini(RushRoster.CHARACTERS.size(),entry.target+tier-1)
  "training_total":return mini(240,ceili(entry.target*[1.0,1.5,2.5][tier-1]))
  "best_combo":return entry.target+(tier-1)*15
 return entry.target*[1,3,6][tier-1]
static func gate(data:Dictionary,tier:int) -> bool:
 if tier<=1:return true
 if tier==2:return metric(data,"wins")>=5 and metric(data,"boss_kos")>=5
 return metric(data,"wins")>=15 and metric(data,"boss_kos")>=30 and metric(data,"hard_wins")>=2
static func gate_text(tier:int) -> String:
 if tier<=1:return "BRONZE / Complete the objective"
 if tier==2:return "SILVER / 5 wins + 5 boss KOs"
 return "GOLD / 15 wins + 30 boss KOs + 2 hard wins"
static func evaluate(data:Dictionary) -> Array:
 var unlocked:Array=[]
 if not data.progress.has("badges"):data.progress.badges={}
 if not data.progress.has("badge_tiers"):data.progress.badge_tiers={}
 for entry in catalog():
  var before:=rank(data,entry.id);var current:=before
  while current<3 and gate(data,current+1) and metric(data,entry.metric)>=target(entry,current+1):current+=1
  if current>0:
   data.progress.badges[entry.id]=true;data.progress.badge_tiers[entry.id]=current
  if current>before:unlocked.append(entry.id)
 return unlocked
static func bonuses(data:Dictionary) -> Dictionary:
 var total:={"health":0.0,"power":0.0,"cooldown":0.0}
 for entry in catalog():total[entry.bonus]+=rank(data,entry.id)*{"health":.20,"power":.04,"cooldown":.0004}[entry.bonus]
 return total
static func reward(entry:Dictionary) -> String:return {"health":"+0.2 HP / stage","power":"+0.04 POWER / stage","cooldown":"-0.04% COOLDOWN / stage"}[entry.bonus]
static func requirement(entry:Dictionary,tier:int=1) -> String:
 var metric:String=entry.metric;var goal:=target(entry,tier)
 if metric.begins_with("clears_"):return "Win this mode %d times"%goal
 if metric.begins_with("wins_"):return "Win this venue %d times"%goal
 if metric.begins_with("casts_"):return "Cast %s %d times"%[metric.trim_prefix("casts_").to_upper(),goal]
 return {"total_kos":"Score %d KOs","best_combo":"Reach a %d combo","boss_kos":"Defeat %d bosses","training_total":"Buy %d GYM levels","highest_skill":"Reach skill level %d","fighters_owned":"Own %d fighters","ultimates":"Use %d ultimates","dodges":"Dodge %d times","ranged_kos":"Score %d ranged KOs","support_triggers":"Trigger companions %d times","perfect_counters":"Land %d perfect counters","guard_breaks":"Break boss guard %d times"}.get(metric,"Reach %d")%goal
