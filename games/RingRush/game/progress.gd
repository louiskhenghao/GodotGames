class_name RushProgress
extends RefCounted
## Ring Rush progression; currency and result metadata settle in one core save commit.
static func settle(store: CoreSaveStore, id: String, coins: int, stage: int, kills: int, won: bool, challenge: String = "classic", waves: int = 0, records: Dictionary = {}) -> bool:
	if id.is_empty(): return false
	if store.data.transactions.has(id): return true
	var next := store.data.duplicate(true)
	next.coins += maxi(0, coins)
	next.transactions[id] = true
	var progress: Dictionary = next.progress
	progress.total_kos = int(progress.get("total_kos", 0)) + maxi(0, kills)
	progress.best_kos = maxi(int(progress.get("best_kos", 0)), kills)
	progress.runs = int(progress.get("runs", 0)) + 1
	if won and challenge!="rift":
		progress.unlocked_stage = maxi(int(progress.get("unlocked_stage", 0)), RushChallenges.next_stage(stage))
		progress["wins_" + str(stage)] = int(progress.get("wins_" + str(stage), 0)) + 1
	progress["best_wave_"+challenge] = maxi(int(progress.get("best_wave_"+challenge,0)),waves)
	if won: progress["clears_"+challenge] = int(progress.get("clears_"+challenge,0))+1
	progress.best_combo=maxi(int(progress.get("best_combo",0)),int(records.get("best_combo",0)))
	for key in ["ranged_kos","support_triggers","perfect_counters","guard_breaks","boss_kos","ultimates","dodges","casts_barrage","casts_quake","casts_cyclone","casts_thunder","casts_dragon","casts_meteor","casts_pulse","casts_orb"]:
		progress[key]=int(progress.get(key,0))+maxi(0,int(records.get(key,0)))
	var badges:=RushAchievements.evaluate(next)
	progress.last_badges=badges
	progress.last_result={"id":id,"coins":maxi(0,coins),"won":won,"bonus_claimed":false}
	progress.erase("pending_run")
	return store.commit(next)

static func checkpoint(store: CoreSaveStore, id: String, coins: int, stage: int, kills: int, state: Dictionary = {}) -> bool:
	var next := store.data.duplicate(true)
	next.progress.pending_run = {"id": id, "coins": coins, "stage": stage, "kills": kills, "state":state}
	return store.commit(next)

static func recover(store: CoreSaveStore) -> int:
	var pending = store.data.progress.get("pending_run", {})
	if not pending is Dictionary or not pending.has("id"): return 0
	var coins := ceili(maxi(0,int(pending.get("coins",0)))*float(pending.get("state",{}).get("growth",{}).get("coins",1)))
	if settle(store, str(pending.id), coins, int(pending.get("stage", 0)), int(pending.get("kills", 0)), false,str(pending.get("state",{}).get("run_mode","classic")),int(pending.get("state",{}).get("completed_waves",0)),pending.get("state",{}).get("records",{})): return coins
	return -1
