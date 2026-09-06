class_name RushTraining
extends RefCounted
## Small, linear permanent gains. Display and gameplay read the same bounded curve.
const MAX_LEVEL:=30
const RANKS:=["BRONZE","SILVER","GOLD","PLATINUM","DIAMOND","MASTER"]
const COLORS:=[Color("dca47b"),Color("c7dbea"),Color("ffd275"),Color("8cf2d1"),Color("8cd9ff"),Color("d6a3ff")]
static func level(store:CoreSaveStore,id:String) -> int:return clampi(int(store.data.progress.get(id,0)),0,MAX_LEVEL)
static func tier(rank:int) -> int:return clampi((maxi(1,rank)-1)/5,0,5)
static func total(store:CoreSaveStore) -> int:
 var sum:=0
 for entry in RushBalance.TRAINING:sum+=level(store,entry.id)
 return sum
static func league(store:CoreSaveStore) -> int:
 var sum:=total(store)
 return 5 if sum>=200 else (4 if sum>=140 else (3 if sum>=90 else (2 if sum>=50 else (1 if sum>=20 else 0))))
static func buy(store:CoreSaveStore,id:String) -> bool:
 var known:=false
 for entry in RushBalance.TRAINING:
  if entry.id==id:known=true
 var rank:=level(store,id);var cost:=RushBalance.training_cost(rank)
 if not known or rank>=MAX_LEVEL or store.data.coins<cost:return false
 var next:=store.data.duplicate(true)
 next.coins-=cost;next.progress[id]=rank+1
 RushAchievements.evaluate(next)
 return store.commit(next)
static func value(fighter:Dictionary,id:String,rank:int) -> float:
 rank=clampi(rank,0,MAX_LEVEL)
 match id:
  "power":return fighter.damage*(1+rank*.008)
  "health":return fighter.hp*(1+rank*.012)
  "charge":return 25+rank*.5
  "footwork":return fighter.speed*(1+rank*.005)
  "mastery":return 100-rank*.35
  "grit":return rank*.2
  "recovery":return rank*.12
  "fortune":return rank*.5
 return 0
static func display_value(fighter:Dictionary,id:String,rank:int) -> String:
 var amount:=value(fighter,id,rank)
 match id:
  "footwork":return "%.2f m/s"%amount
  "charge","mastery","fortune":return "%.1f%%"%amount
  "grit","recovery":return "%.1f%%"%amount
 return "%.1f"%amount
