class_name RushBootstrap
extends RefCounted
## Game-only welcome economy and migration. The mobile core knows no fighters.
const RETIRED:={"rattle":{"price":320,"move":"barrage"},"shade":{"price":480,"move":"dragon"},"hex":{"price":620,"move":"thunder"}}
static func prepare(store:CoreSaveStore) -> bool:
 if OS.has_feature("playtest") and not store.data.transactions.has("playtest-welcome-v1"):
  if not store.grant("playtest-welcome-v1",1200):return false
 if not migrate(store):return false
 var next:=store.data.duplicate(true)
 var changed:bool=not next.progress.has("badge_tiers")
 if int(next.progress.get("wins_4",0))>0 and int(next.progress.get("unlocked_stage",0))<6:
  next.progress.unlocked_stage=6;changed=true
 var state=next.progress.get("pending_run",{}).get("state",{})
 if state is Dictionary and state.get("version")==1 and not state.has("growth"):
  state.growth=RushGrowth.legacy(store);changed=true
 var badges:=RushAchievements.evaluate(next)
 return store.commit(next) if changed or not badges.is_empty() else true
static func migrate(store:CoreSaveStore) -> bool:
 if store.data.transactions.has("human-roster-v2"):return true
 var next:=store.data.duplicate(true)
 var unlocks:Dictionary=next.progress.get("unlocks",{})
 for id in RETIRED:
  if unlocks.get("character:"+id,false):
   next.coins+=RETIRED[id].price
   unlocks.erase("character:"+id)
   unlocks["move:"+RETIRED[id].move]=true
 next.progress.unlocks=unlocks
 if next.progress.get("selected_character") in RETIRED:next.progress.selected_character="atlas"
 var state:Dictionary=next.progress.get("pending_run",{}).get("state",{})
 if state.get("character") in RETIRED:state.character="atlas"
 if state.get("run_mode","")!="rift":
  for enemy in state.get("enemies",[]):
   enemy.role={"bone":"runner","revenant":"charger","hexer":"spark"}.get(enemy.get("role",""),enemy.get("role","rookie"))
 next.transactions["human-roster-v2"]=true
 return store.commit(next)
