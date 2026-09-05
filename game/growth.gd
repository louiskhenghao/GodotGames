class_name RushGrowth
extends RefCounted
## Frozen at fight start. Buying upgrades never changes a resumed challenge.
static func snapshot(store:CoreSaveStore,fighter:Dictionary,move:String,contract:bool=false) -> Dictionary:
 var total:=RushTraining.total(store)
 var premium:=maxf(0,(fighter.damage-20)/40)
 var skill_rank:=RushSkillGrowth.level(store,move)
 var pressure:=minf(1,float(total)/240+premium*.15+(skill_rank-1)*.012)
 var badges:=RushAchievements.bonuses(store.data)
 return {"enemy_hp":1+pressure*.65+(.3 if contract else 0.0),"enemy_damage":1+pressure*.3+(.2 if contract else 0.0),"enemy_speed":1+pressure*.06,"skill_level":skill_rank,"cooldown":RushTraining.value(fighter,"mastery",RushTraining.level(store,"mastery"))/100*(1-badges.cooldown),"grit":RushTraining.level(store,"grit")*.006,"recovery":RushTraining.level(store,"recovery")*.003,"coins":1+RushTraining.level(store,"fortune")*.01+(.25 if contract else 0.0),"contract":contract}

static func legacy(store:CoreSaveStore) -> Dictionary:
 # Old runs had no rival scaling, skill ranks or new training tracks.
 return {"enemy_hp":1.0,"enemy_damage":1.0,"enemy_speed":1.0,"skill_level":1,"cooldown":1-clampi(int(store.data.progress.get("mastery",0)),0,5)*.04,"grit":0.0,"recovery":0.0,"coins":1.0,"contract":false}
