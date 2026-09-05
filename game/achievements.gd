class_name RushAchievements
extends RefCounted
## Evaluation joins the caller's save transaction. Badges cannot be farmed by retrying.
static func catalog() -> Array:
 var list:Array=[]
 for i in 4:_add(list,"ko_"+str(i),["FIRST BLOOD","HEAVY HITTER","CROWD BREAKER","KO LEGEND"][i],"COMBAT","total_kos",[10,100,500,2000][i],"fist")
 for i in 3:_add(list,"combo_"+str(i),["IN THE FLOW","UNTOUCHABLE","COMBO KING"][i],"COMBAT","best_combo",[10,25,50][i],"bolt")
 for i in 2:_add(list,"boss_"+str(i),["GIANT SLAYER","BOSS HUNTER"][i],"COMBAT","boss_kos",[1,25][i],"crown")
 for mode in RushWaveDirector.MODES:
  if mode.id!="classic":_add(list,"clear_"+mode.id,mode.name,"VICTORIES","clears_"+mode.id,1,mode.icon)
 for i in 5:_add(list,"venue_"+str(i),["FIRST BELT","STREET JUSTICE","SKY HIGH","FORGED IN FIRE","DAWN MASTER"][i],"VICTORIES","wins_"+str(i),1,"stairs")
 for i in 3:_add(list,"gym_"+str(i),["SHOW UP","GOLD STANDARD","MASTER CLASS"][i],"GROWTH","training_total",[5,50,200][i],"dumbbell")
 for i in 3:_add(list,"skill_"+str(i),["SHARPENED","AWAKENED","ASCENDED"][i],"GROWTH","highest_skill",[2,5,10][i],"nova")
 for i in 3:_add(list,"roster_"+str(i),["TAG TEAM","FIGHT CLUB","FULL ROSTER"][i],"GROWTH","fighters_owned",[2,6,9][i],"shield")
 for entry in [["quake","FAULT MAKER","quake"],["cyclone","STORM RIDER","cyclone"],["thunder","LIVE CURRENT","bolt"]]:_add(list,"cast_"+entry[0],entry[1],"STYLE","casts_"+entry[0],20,entry[2])
 _add(list,"ultimate","MAIN EVENT","STYLE","ultimates",10,"crown")
 _add(list,"dodge","SLIP ARTIST","STYLE","dodges",50,"dash")
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
 return maxi(0,int(p.get(id,0)))
static func evaluate(data:Dictionary) -> Array:
 var unlocked:Array=[]
 if not data.progress.has("badges"):data.progress.badges={}
 for entry in catalog():
  if not data.progress.badges.get(entry.id,false) and metric(data,entry.metric)>=entry.target:
   data.progress.badges[entry.id]=true;unlocked.append(entry.id)
 return unlocked
static func bonuses(data:Dictionary) -> Dictionary:
 var total:={"health":0.0,"power":0.0,"cooldown":0.0}
 for entry in catalog():
  if data.progress.get("badges",{}).get(entry.id,false):total[entry.bonus]+={"health":1.0,"power":.2,"cooldown":.002}[entry.bonus]
 return total
static func reward(entry:Dictionary) -> String:return {"health":"+1 HP","power":"+0.2 POWER","cooldown":"-0.2% COOLDOWN"}[entry.bonus]
static func requirement(entry:Dictionary) -> String:
 var metric:String=entry.metric
 if metric.begins_with("clears_"):return "Win this mode"
 if metric.begins_with("wins_"):return "Win this venue"
 if metric.begins_with("casts_"):return "Cast %s %d times"%[metric.trim_prefix("casts_").to_upper(),entry.target]
 return {"total_kos":"Score %d KOs","best_combo":"Reach a %d combo","boss_kos":"Defeat %d bosses","training_total":"Buy %d GYM levels","highest_skill":"Reach skill level %d","fighters_owned":"Own %d fighters","ultimates":"Use %d ultimates","dodges":"Dodge %d times"}.get(metric,"Reach %d")%entry.target
