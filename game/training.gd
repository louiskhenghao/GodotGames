class_name RushTraining
extends RefCounted
## Game rules wrap the generic atomic store; all purchases re-check the live balance.
const MAX_LEVEL:=5
static func level(store:CoreSaveStore,id:String) -> int:
	return clampi(int(store.data.progress.get(id,0)),0,MAX_LEVEL)
static func buy(store:CoreSaveStore,id:String) -> bool:
	var known:=false
	for entry in RushBalance.TRAINING:
		if entry.id==id:known=true
	if not known or level(store,id)>=MAX_LEVEL:return false
	return store.buy_upgrade(id,RushBalance.training_cost(level(store,id)))
static func value(fighter:Dictionary,id:String,rank:int) -> float:
	match id:
		"power":return fighter.damage+rank*3
		"health":return fighter.hp+rank*10
		"charge":return minf(100,35+rank*10)
		"footwork":return fighter.speed*(1+rank*.04)
		"mastery":return (1-rank*.04)*100
	return 0
static func display_value(fighter:Dictionary,id:String,rank:int) -> String:
	var amount:=value(fighter,id,rank)
	match id:
		"footwork":return "%.2f m/s"%amount
		"charge","mastery":return "%d%%"%amount
	return str(int(amount))
