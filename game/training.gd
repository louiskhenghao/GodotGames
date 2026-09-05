class_name RushTraining
extends RefCounted
## Thirty levels per discipline. Early purchases retain their original benefits.
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
 var first:=mini(5,rank);var extra:=maxi(0,rank-5)
 match id:
  "power":return fighter.damage+first*3+extra*1.5
  "health":return fighter.hp+first*10+extra*6
  "charge":return minf(100,35+first*10+extra*.6)
  "footwork":return fighter.speed*(1+first*.04+extra*.008)
  "mastery":return (1-first*.04-extra*.008)*100
  "grit":return rank*.6
  "recovery":return rank*.3
  "fortune":return rank
 return 0
static func display_value(fighter:Dictionary,id:String,rank:int) -> String:
 var amount:=value(fighter,id,rank)
 match id:
  "footwork":return "%.2f m/s"%amount
  "charge","mastery","fortune":return "%d%%"%amount
  "grit","recovery":return "%.1f%%"%amount
 return "%.0f"%amount
