class_name CoreSaveStore
extends RefCounted
## One JSON document: rewards and their transaction IDs commit together.
signal changed
var path: String
var data: Dictionary = {}
var last_error: Error = OK
var recovered_from_backup := false
var unsupported_version := false

func _init(save_path: String = "user://profile.json") -> void:
	path = save_path
	data = defaults()

func defaults() -> Dictionary:
	return {"version": 1, "coins": 0, "entitlements": {}, "transactions": {}, "progress": {}, "settings": {"effects": true, "haptics": true}}

func load_profile() -> void:
	recovered_from_backup = false
	unsupported_version = false
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(candidate)) != OK:
			continue
		var parsed = parser.data
		if candidate == path and parsed is Dictionary and parsed.get("version", 1) != 1:
			unsupported_version = true
			last_error = ERR_UNAVAILABLE
			return
		if _valid(parsed):
			data = parsed
			recovered_from_backup = candidate != path
			return

func _valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if value.has("reward_receipts") and not value.reward_receipts is Dictionary:return false
	return value.get("version") == 1 and value.get("coins") is float and value.coins >= 0 and value.get("entitlements") is Dictionary and value.get("transactions") is Dictionary and value.get("progress") is Dictionary and value.get("settings") is Dictionary

func commit(next: Dictionary) -> bool:
	if unsupported_version:
		last_error = ERR_UNAVAILABLE
		return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = FileAccess.get_open_error()
		return false
	file.store_string(JSON.stringify(next))
	file.flush()
	last_error = file.get_error()
	file.close()
	if last_error != OK:
		return false
	# Keep the previous complete document. Rename on the same filesystem is atomic.
	if FileAccess.file_exists(path) and not recovered_from_backup:
		last_error = DirAccess.copy_absolute(path, path + ".bak")
		if last_error != OK:
			return false
	last_error = DirAccess.rename_absolute(path + ".tmp", path)
	if last_error != OK:
		return false
	data = next
	recovered_from_backup = false
	changed.emit()
	return true

func grant(transaction: String, coins: int = 0, entitlement: String = "") -> bool:
	if transaction.is_empty() or coins < 0 or data.transactions.has(transaction):
		return false
	var next := data.duplicate(true)
	next.coins += coins
	next.transactions[transaction] = true
	if not entitlement.is_empty():
		next.entitlements[entitlement] = true
	return commit(next)

func buy_upgrade(key: String, cost: int) -> bool:
	if cost < 0 or data.coins < cost:
		return false
	var next := data.duplicate(true)
	next.coins -= cost
	next.progress[key] = int(next.progress.get(key, 0)) + 1
	return commit(next)

func set_setting(key: String, value: bool) -> bool:
	var next := data.duplicate(true)
	next.settings[key] = value
	return commit(next)
