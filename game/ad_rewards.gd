class_name RushAdRewards
extends RefCounted
## Apply earned receipts and game benefit in one save commit. Restart-safe and idempotent.
static func claim(store:CoreSaveStore,id:String) -> Dictionary:
	var receipts:Dictionary=store.data.get("reward_receipts",{})
	if not receipts.get(id) is Dictionary:return {"ok":false}
	var receipt:Dictionary=receipts[id]
	if not receipt.get("context",{}) is Dictionary:return {"ok":false}
	var context:Dictionary=receipt.get("context",{})
	var run_id:String=context.get("run_id","")
	var next:=store.data.duplicate(true)
	var result:={"ok":false,"run_id":run_id}
	var key:="benefit:"+id
	if not next.transactions.has(key):
		if receipt.get("placement")=="revive":
			var pending:Dictionary=next.progress.get("pending_run",{})
			var state:Dictionary=pending.get("state",{})
			if pending.get("id")==run_id and RushRunSnapshot.valid(state) and state.get("knocked_out",false) and not state.get("revive_used",false):
				state.hp=maxf(1,float(state.max_hp)*.60)
				state.revive_used=true
				state.knocked_out=false
				state.protection=3.0
				result={"ok":true,"run_id":run_id,"benefit":"revive","hp":state.hp}
		elif receipt.get("placement")=="victory_bonus":
			var record:Dictionary=next.progress.get("last_result",{})
			if record.get("id")==run_id and record.get("won",false) and not record.get("bonus_claimed",false):
				var bonus:=ceili(maxf(0,float(record.coins))*.5)
				next.coins+=bonus
				record.bonus_claimed=true
				record.bonus_coins=bonus
				result={"ok":true,"run_id":run_id,"benefit":"victory_bonus","coins":bonus}
	if result.get("ok",false): next.progress.last_rewarded_run=run_id
	next.transactions[key]=true
	next.reward_receipts.erase(id)
	if not store.commit(next):return {"ok":false,"retry":true}
	return result
