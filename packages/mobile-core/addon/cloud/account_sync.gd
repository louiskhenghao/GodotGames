class_name CoreAccountSync
extends Node
## One account cache per user, optimistic cloud revisions, durable local-first progress.
signal changed
signal profile_loaded
var api := CoreApiClient.new()
var store: CoreSaveStore
var identity_store: CoreSaveStore
var guest_path := ""
var user_id := ""
var email := ""
var verified := false
var busy := false
var status := "Saved on this device"
var conflict: Dictionary = {}
var safe_to_sync: Callable
var game_id := ""
var retry_at := 0.0
var _applying := false
var _auth_user := ""
var _new_cache := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(api)

func configure(profile: CoreSaveStore, id: String, url: String, safe: Callable) -> void:
	if store != null and store.changed.is_connected(_local_changed): store.changed.disconnect(_local_changed)
	store = profile
	guest_path = store.path
	game_id = id
	safe_to_sync = safe
	api.configure(url)
	identity_store = CoreSaveStore.new(guest_path + ".account-index.json")
	identity_store.load_profile()
	var cached := str(identity_store.data.progress.get("user_id", ""))
	if _valid_user(cached):
		if _switch_profile(cached):
			email = str(identity_store.data.progress.get("email", ""))
			status = "On device · sign in to sync"
	store.changed.connect(_local_changed)

func _valid_user(value: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
	return regex.search(value) != null

func _switch_profile(id: String) -> bool:
	var target := guest_path if id.is_empty() else guest_path + ".user-" + id + ".json"
	if store.path != target:
		_new_cache = not FileAccess.file_exists(target) and not FileAccess.file_exists(target + ".bak")
		var candidate := CoreSaveStore.new(target)
		candidate.load_profile()
		if candidate.unsupported_version or candidate.last_error != OK:
			status = "Could not open this profile. Your files were kept."
			return false
		store.path = target
		store.data = candidate.data
		store.recovered_from_backup = candidate.recovered_from_backup
		store.unsupported_version = false
	user_id = id
	return true

func _local_changed() -> void:
	if _applying: return
	retry_at = Time.get_ticks_msec() / 1000.0 + 3.0
	if not user_id.is_empty(): status = "On device · sync pending" if verified else "On device · sign in to sync"
	changed.emit()

func _process(_delta: float) -> void:
	if store == null or busy or not conflict.is_empty() or not verified or api.access_token.is_empty(): return
	if Time.get_ticks_msec() / 1000.0 < retry_at or not safe_to_sync.call(): return
	retry_at = Time.get_ticks_msec() / 1000.0 + 60.0
	sync_now()

func _start() -> bool:
	if busy or not safe_to_sync.call(): return false
	busy = true
	status = "Connecting…"
	changed.emit()
	return true

func _finish(text: String) -> void:
	busy = false
	_new_cache = false
	status = text
	retry_at = Time.get_ticks_msec() / 1000.0 + 60.0
	changed.emit()

func _error(result: Dictionary) -> void:
	var code := str(result.get("error", "OFFLINE"))
	if result.get("status", 0) == 401: verified = false
	var messages := {
		"NOT_CONFIGURED": "Cloud service is not configured. Local play is available.",
		"OFFLINE": "Offline · progress saved on this device. We will retry.",
		"INVALID_CREDENTIALS": "Email or password is incorrect.",
		"SIGN_IN_REQUIRED": "Please sign in again. Local progress is safe.",
		"INVALID_ACCESS_TOKEN": "Please sign in again. Local progress is safe.",
		"SESSION_REVOKED": "Session ended. Sign in again to sync.",
		"EMAIL_VERIFICATION_REQUIRED": "Verify your email, then tap CHECK VERIFICATION.",
		"RATE_LIMITED": "Too many attempts. Wait a few minutes and try again.",
		"GAME_UNAVAILABLE": "Cloud saves are not enabled for this game yet.",
		"INVALID_REQUEST": "Check your email and password (12–128 characters).",
		"SAVE_SCHEMA_DOWNGRADE": "Update the game before syncing this save."
	}
	_finish(messages.get(code, "Sync unavailable. Local progress is safe; try again later."))

func email_action(action: String, address: String, password := "") -> void:
	if action not in ["register", "forgot-password", "resend-verification"] or not _start(): return
	var body := {"email": address.strip_edges().to_lower()}
	if action == "register": body.password = password
	var result := await api.call_api(HTTPClient.METHOD_POST, "/v1/auth/" + action, body, false)
	if not result.ok: _error(result); return
	_finish("Check your email to " + ("reset your password." if action == "forgot-password" else "verify your account, then sign in."))

func login(address: String, password: String) -> void:
	if not _start(): return
	var result := await api.call_api(HTTPClient.METHOD_POST, "/v1/auth/login", {"email": address.strip_edges().to_lower(), "password": password}, false)
	if not result.ok: _error(result); return
	var id := str(result.body.get("userId", ""))
	if not _valid_user(id): _finish("Invalid account response. Local progress was kept."); return
	api.accept_tokens(result.body)
	_auth_user = id
	email = address.strip_edges().to_lower()
	await _verify_and_enter()

func check_verification() -> void:
	if not _start(): return
	await _verify_and_enter()

func _verify_and_enter() -> void:
	var result := await api.call_api(HTTPClient.METHOD_GET, "/v1/auth/me")
	if not result.ok: _error(result); return
	verified = result.body.get("emailVerified", false)
	if not verified: _finish("Verify your email, then tap CHECK VERIFICATION."); return
	if str(result.body.get("userId", "")) != _auth_user:
		api.forget(); verified = false; _finish("Account response mismatch. Please sign in again."); return
	var previous_path := store.path
	var previous_data := store.data
	var previous_user := user_id
	if not _switch_profile(_auth_user):
		api.forget(); verified = false; _finish(status); return
	var index := identity_store.data.duplicate(true)
	index.progress = {"user_id": user_id, "email": email}
	if not identity_store.commit(index):
		store.path = previous_path
		store.data = previous_data
		user_id = previous_user
		api.forget(); verified = false
		_finish("Could not save the account switch. Free storage and retry.")
		return
	conflict.clear()
	profile_loaded.emit()
	await _sync()

func logout() -> void:
	if not _start(): return
	if not api.access_token.is_empty():
		await api.call_api(HTTPClient.METHOD_POST, "/v1/auth/logout")
	# Tokens were never persisted. Each account's offline cache stays in its own file.
	api.forget()
	verified = false
	_auth_user = ""
	var index := identity_store.data.duplicate(true)
	index.progress = {}
	if not identity_store.commit(index): _finish("Could not sign out locally. Free storage and retry."); return
	if not _switch_profile(""): _finish(status); return
	email = ""
	conflict.clear()
	profile_loaded.emit()
	_finish("Guest profile · account progress remains on this device")

func sync_now() -> void:
	if not _start(): return
	if not verified or api.access_token.is_empty(): _finish("Sign in to sync. Offline progress is saved locally."); return
	if not conflict.is_empty(): _finish("Choose which progress to keep before syncing."); return
	await _sync()

func _path(suffix: String) -> String:
	return "/v1/games/" + game_id + suffix

func _commit(next: Dictionary) -> bool:
	_applying = true
	var saved := store.commit(next)
	_applying = false
	if not saved: _finish("Could not save to this device. Free storage and retry.")
	return saved

func _sync(choice := "") -> void:
	var before := CoreCloudProfile.digest(store.data)
	var result := await api.call_api(HTTPClient.METHOD_GET, _path("/save"))
	if not result.ok: _error(result); return
	if before != CoreCloudProfile.digest(store.data): _finish("On device · new progress queued for sync"); return
	var remote = result.body.get("save")
	if remote != null and (not remote is Dictionary or remote.get("schemaVersion") != 1 or not CoreCloudProfile.valid(remote.get("payload"))):
		_finish("Cloud save needs a compatible game version. Local progress was kept."); return
	var local_revision := str(store.data.get("cloud", {}).get("revision", "0"))
	var remote_revision := str(remote.revision) if remote != null else "0"
	if not choice.is_empty() and remote_revision != str(conflict.get("revision", "0")):
		_set_conflict(remote); return # A third device changed the save while the choice was open.
	if choice == "cloud" and remote != null:
		if not _load_remote(remote): return
	elif choice == "guest":
		var guest := CoreSaveStore.new(guest_path); guest.load_profile()
		if guest.last_error != OK: _finish("Guest save is unavailable. Its file was kept."); return
		if not _commit(CoreCloudProfile.imported_guest(guest.data)): return
	elif choice == "new":
		if not _commit(store.defaults()): return
	elif choice == "device":
		var next := store.data.duplicate(true)
		if not next.has("cloud"): next.cloud = {}
		next.cloud.revision = remote_revision
		if not _commit(next): return
	elif choice != "new":
		if remote != null and remote_revision != local_revision:
			var same := CoreCloudProfile.digest(remote.payload) == CoreCloudProfile.digest(store.data)
			if CoreCloudProfile.dirty(store.data) and not same and local_revision != "0": _set_conflict(remote); return
			if local_revision == "0" and not _new_cache and CoreCloudProfile.dirty(store.data) and not same: _set_conflict(remote); return
			if not _load_remote(remote): return
		elif remote == null and local_revision != "0": _set_conflict(remote); return
		elif remote == null and not store.data.has("cloud"):
			_set_conflict(null, "first"); return
	conflict.clear()
	# Reconcile paid grants/refunds before publishing a cursor; never trust a local paid flag.
	var next := store.data.duplicate(true)
	if not next.has("cloud"): next.cloud = {}
	next.cloud.revision = remote_revision
	var starting_digest := CoreCloudProfile.digest(store.data)
	for _page in 100:
		var ledger := await api.call_api(HTTPClient.METHOD_GET, _path("/ledger?after=" + str(next.cloud.get("purchase_cursor", "0"))))
		if not ledger.ok: _error(ledger); return
		if not ledger.body.get("entries") is Array or not ledger.body.get("hasMore") is bool:
			_finish("Cloud service returned an incompatible response. Local progress was kept."); return
		next = CoreCloudProfile.apply_ledger(next, ledger.body.entries)
		if not ledger.body.hasMore: break
		if _page == 99: _finish("Large account history. Contact support to finish syncing."); return
	var inventory := await api.call_api(HTTPClient.METHOD_GET, _path("/inventory"))
	if not inventory.ok: _error(inventory); return
	if not inventory.body.get("managedEntitlements") is Array or not inventory.body.get("entitlements") is Array:
		_finish("Cloud inventory is unavailable. Local progress was kept."); return
	for key in inventory.body.managedEntitlements: next.entitlements.erase(key)
	for key in inventory.body.entitlements: next.entitlements[key] = true
	if str(inventory.body.cursor) != str(next.cloud.get("purchase_cursor", "0")):
		_finish("Purchase update arriving · sync will retry"); return
	if starting_digest != CoreCloudProfile.digest(store.data): _finish("On device · new progress queued for sync"); return
	if not _commit(next): return
	var sent_digest := CoreCloudProfile.digest(next)
	if remote != null and sent_digest == CoreCloudProfile.digest(remote.payload) and str(next.cloud.get("purchase_cursor", "0")) == str(remote.purchaseCursor):
		next.cloud.digest = sent_digest
		next.cloud.updated_at = remote.updatedAt
		if not _commit(next): return
		profile_loaded.emit()
		_finish("Synced · progress safe in the cloud"); return
	var upload := await api.call_api(HTTPClient.METHOD_PUT, _path("/save"), {"expectedRevision": remote_revision, "schemaVersion": 1, "purchaseCursor": str(next.cloud.get("purchase_cursor", "0")), "payload": CoreCloudProfile.payload(next)})
	if not upload.ok:
		if upload.get("error") == "SAVE_REVISION_CONFLICT":
			_finish("Another device saved progress. Checking for a conflict…")
			retry_at = 0.0
		else: _error(upload)
		return
	if not upload.body.get("save") is Dictionary or not upload.body.save.has("revision") or not upload.body.save.has("updatedAt"):
		_finish("Save response was incomplete. We will check again before retrying."); return
	# Preserve local changes made during the request; only mark the exact sent snapshot synchronized.
	var current := store.data.duplicate(true)
	current.cloud.revision = str(upload.body.save.revision)
	current.cloud.digest = sent_digest
	current.cloud.updated_at = upload.body.save.updatedAt
	if not _commit(current): return
	profile_loaded.emit()
	_finish("On device · sync pending" if CoreCloudProfile.dirty(current) else "Synced · progress safe in the cloud")

func _load_remote(remote: Dictionary) -> bool:
	var next := CoreCloudProfile.payload(remote.payload)
	next.cloud = {"revision": str(remote.revision), "purchase_cursor": str(remote.purchaseCursor), "digest": CoreCloudProfile.digest(next), "updated_at": remote.updatedAt}
	var saved := _commit(next)
	if saved: profile_loaded.emit()
	return saved

func _set_conflict(remote: Variant, kind := "conflict") -> void:
	conflict = {"kind": kind, "remote": remote, "revision": str(remote.revision) if remote != null else "0"}
	_finish("Choose your starting progress" if kind == "first" else "Two saves found · choose which to keep")

func resolve(choice: String) -> void:
	if conflict.is_empty() or not verified or api.access_token.is_empty(): return
	var choices := ["guest", "new"] if conflict.kind == "first" else ["device", "cloud"]
	if choice not in choices or not _start(): return
	# Keep an explicit local snapshot before either conflict choice, in addition to the rolling backup.
	var archive := CoreSaveStore.new(store.path + ".conflict-" + str(Time.get_unix_time_from_system()).replace(".", "-") + ".json")
	if not archive.commit(store.data.duplicate(true)): _finish("Could not back up this save. Free storage and retry."); return
	await _sync(choice)
