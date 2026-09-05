class_name RushProgress
extends RefCounted
## Ring Rush progression; currency and result metadata settle in one core save commit.
static func settle(store: CoreSaveStore, id: String, coins: int, stage: int, kills: int, won: bool) -> bool:
	if id.is_empty(): return false
	if store.data.transactions.has(id): return true
	var next := store.data.duplicate(true)
	next.coins += maxi(0, coins)
	next.transactions[id] = true
	var progress: Dictionary = next.progress
	progress.total_kos = int(progress.get("total_kos", 0)) + maxi(0, kills)
	progress.best_kos = maxi(int(progress.get("best_kos", 0)), kills)
	progress.runs = int(progress.get("runs", 0)) + 1
	if won:
		progress.unlocked_stage = maxi(int(progress.get("unlocked_stage", 0)), mini(stage + 1, 2))
		progress["wins_" + str(stage)] = int(progress.get("wins_" + str(stage), 0)) + 1
	progress.erase("pending_run")
	return store.commit(next)

static func checkpoint(store: CoreSaveStore, id: String, coins: int, stage: int, kills: int) -> bool:
	var next := store.data.duplicate(true)
	next.progress.pending_run = {"id": id, "coins": coins, "stage": stage, "kills": kills}
	return store.commit(next)

static func recover(store: CoreSaveStore) -> int:
	var pending = store.data.progress.get("pending_run", {})
	if not pending is Dictionary or not pending.has("id"): return 0
	var coins := maxi(0, int(pending.get("coins", 0)))
	if settle(store, str(pending.id), coins, int(pending.get("stage", 0)), int(pending.get("kills", 0)), false): return coins
	return -1
