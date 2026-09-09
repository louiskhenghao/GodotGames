extends SceneTree
var checks := 0
var failures := 0
var instances: Array[CoreAccountSync] = []
var prefix := "user://cloud-test-" + Crypto.new().generate_random_bytes(6).hex_encode()
const ALICE := "11111111-1111-4111-8111-111111111111"
const BOB := "22222222-2222-4222-8222-222222222222"
class Server extends RefCounted:
	var saves: Dictionary = {}
	var offline := false
	var lose_ack := false
	var on_upload: Callable
	var unverified := false
	var invalid_refresh := false
	var refreshes := 0
	func send(method: int, path: String, body: Dictionary, bearer: String) -> Dictionary:
		if offline: return {"ok": false, "status": 0, "error": "OFFLINE"}
		if path.ends_with("/login"):
			var user := ALICE if body.email == "alice@example.test" else BOB
			return ok({"userId": user, "accessToken": user, "refreshToken": "refresh"})
		if path.ends_with("/refresh"):
			refreshes += 1
			return {"ok": false, "status": 401, "error": "INVALID_REFRESH_TOKEN"}
		if invalid_refresh: return {"ok": false, "status": 401, "error": "SESSION_REVOKED"}
		if path.ends_with("/me"): return ok({"userId": bearer, "emailVerified": not unverified})
		if path.ends_with("/logout"): return ok({})
		if path.contains("/ledger"): return ok({"entries": [], "hasMore": false, "nextCursor": "0"})
		if path.ends_with("/inventory"): return ok({"managedEntitlements": ["remove_ads", "gold_gloves"], "entitlements": [], "cursor": "0"})
		if path.ends_with("/save"):
			if method == HTTPClient.METHOD_GET: return ok({"save": saves.get(bearer)})
			var current := str(saves.get(bearer, {}).get("revision", "0"))
			if current != str(body.expectedRevision): return {"ok": false, "status": 409, "error": "SAVE_REVISION_CONFLICT"}
			saves[bearer] = {"revision": str(int(current) + 1), "schemaVersion": 1, "purchaseCursor": body.purchaseCursor, "payload": body.payload.duplicate(true), "updatedAt": "2026-09-09T12:00:00Z"}
			if on_upload.is_valid(): on_upload.call(); on_upload = Callable()
			if lose_ack: lose_ack = false; return {"ok": false, "status": 0, "error": "OFFLINE"}
			return ok({"save": saves[bearer].duplicate(true)})
		return ok({})
	func ok(body: Dictionary) -> Dictionary:
		return {"ok": true, "status": 200, "body": body, "error": ""}
func _initialize(): call_deferred("run")
func check(value: bool, message: String):
	checks += 1
	if not value: failures += 1; push_error(message)
func client(name: String, server: Server) -> CoreAccountSync:
	var service := CoreAccountSync.new(); root.add_child(service)
	var local := CoreSaveStore.new(prefix + name + ".json"); local.load_profile()
	service.configure(local, "ringrush", "https://api.example.test", func(): return true)
	service.set_process(false)
	service.api.transport = server.send
	instances.append(service)
	return service
func run():
	var server := Server.new()
	var a := client("a", server)
	a.store.grant("guest-fight", 120)
	a.store.grant("iap:mock", 0, "remove_ads")
	await a.login("alice@example.test", "test-password-123")
	check(a.verified and a.conflict.get("kind") == "first", "first login asks before importing a guest")
	check(a.store.data.coins == 0, "account starts separate from guest data")
	await a.resolve("guest")
	check(a.store.data.coins == 120 and server.saves[ALICE].payload.coins == 120, "explicit guest import uploads progress")
	check(not a.store.data.entitlements.has("remove_ads") and not a.store.data.transactions.has("iap:mock"), "mock paid rights do not migrate")
	check(not server.saves[ALICE].payload.has("cloud") and not server.saves[ALICE].payload.has("reward_receipts"), "cloud excludes local metadata")
	check(not CoreCloudProfile.dirty(a.store.data), "successful upload records the exact digest")
	server.offline = true
	a.store.grant("offline-fight", 30)
	await a.sync_now()
	check(a.store.data.coins == 150 and a.status.begins_with("Offline"), "offline sync failure preserves rewards")
	var disk := CoreSaveStore.new(a.store.path); disk.load_profile()
	check(disk.data.coins == 150, "offline rewards survive reopening the file")
	var restart := client("a", server)
	check(restart.user_id == ALICE and restart.store.data.coins == 150, "restart opens the last account cache without a network")
	check(restart.api.access_token.is_empty(), "no access or refresh token is persisted")
	server.offline = false
	await restart.login("alice@example.test", "test-password-123")
	check(server.saves[ALICE].payload.coins == 150, "reconnect uploads offline progress")
	var b := client("b", server)
	await b.login("alice@example.test", "test-password-123")
	check(b.store.data.coins == 150 and b.conflict.is_empty(), "second phone downloads the existing cloud save")
	restart.store.grant("device-a", 40)
	b.store.grant("device-b", 70)
	await restart.sync_now()
	await b.sync_now()
	check(b.conflict.get("kind") == "conflict" and b.store.data.coins == 220, "divergent device progress is never overwritten automatically")
	await b.resolve("cloud")
	check(b.store.data.coins == 190 and b.conflict.is_empty(), "explicit cloud choice restores selected progress")
	b.store.grant("device-b-again", 10)
	restart.store.grant("device-a-again", 20)
	await restart.sync_now()
	await b.sync_now()
	await b.resolve("device")
	check(server.saves[ALICE].payload.coins == 200, "explicit device choice replaces cloud without adding balances")
	server.lose_ack = true
	b.store.grant("lost-ack", 5)
	await b.sync_now()
	check(CoreCloudProfile.dirty(b.store.data), "lost acknowledgement leaves progress pending")
	await b.sync_now()
	check(b.conflict.is_empty() and not CoreCloudProfile.dirty(b.store.data) and b.store.data.coins == 205, "lost acknowledgement is recovered without duplicate progress")
	b.store.grant("before-upload", 1)
	server.on_upload = func(): b.store.grant("during-upload", 9)
	await b.sync_now()
	check(b.store.data.coins == 215 and CoreCloudProfile.dirty(b.store.data), "changes during upload are retained and remain pending")
	await b.sync_now()
	check(server.saves[ALICE].payload.coins == 215, "next sync uploads changes made during the previous request")
	var alice_path := b.store.path
	await b.login("bob@example.test", "test-password-123")
	check(b.user_id == BOB and b.store.path != alice_path and b.store.data.coins == 0, "account switch uses a separate local file")
	await b.resolve("new")
	check(server.saves[BOB].payload.coins == 0, "new account cannot inherit the previous account's coins")
	await b.login("alice@example.test", "test-password-123")
	check(b.store.data.coins == 215, "switching back restores the original account")
	server.invalid_refresh = true
	await b.sync_now()
	check(not b.verified and b.store.data.coins == 215 and server.refreshes == 1, "revoked session fails one refresh then keeps local progress")
	server.invalid_refresh = false
	server.unverified = true
	var unverified := client("unverified", server)
	await unverified.login("alice@example.test", "test-password-123")
	check(not unverified.verified and unverified.user_id.is_empty(), "unverified email cannot switch into a cloud profile")
	server.unverified = false
	await unverified.check_verification()
	check(unverified.verified and unverified.store.data.coins == 215, "verification can be completed without restarting login")
	check(CoreCloudProfile.digest({"coins": 120, "version": 1}) == CoreCloudProfile.digest({"coins": 120.0, "version": 1.0}), "JSON transport number normalization does not create false conflicts")
	var interrupted_server := Server.new()
	var first_device := client("interrupted", interrupted_server)
	await first_device.login("alice@example.test", "test-password-123")
	first_device.store.grant("before-first-upload", 75)
	var another_device := client("interrupted-other", interrupted_server)
	await another_device.login("alice@example.test", "test-password-123")
	await another_device.resolve("new")
	var reopened := client("interrupted", interrupted_server)
	await reopened.login("alice@example.test", "test-password-123")
	check(reopened.conflict.get("kind") == "conflict" and reopened.store.data.coins == 75, "unsynced revision-zero account survives restart when another phone creates a cloud save")
	var ledger := CoreSaveStore.new().defaults()
	ledger.coins = 50
	ledger = CoreCloudProfile.apply_ledger(ledger, [{"sequence": "1", "currency": "coins", "amount": "-100"}])
	check(ledger.coins == 0 and ledger.iap_debt == 50, "refunds retain debt instead of silently losing a negative balance")
	ledger = CoreCloudProfile.apply_ledger(ledger, [{"sequence": "1", "currency": "coins", "amount": "-100"}, {"sequence": "2", "currency": "coins", "amount": "200"}])
	check(ledger.coins == 150 and ledger.iap_debt == 0, "ledger cursor prevents replay and settles refund debt")
	check(not CoreCloudProfile.valid({"version": 2}), "incompatible cloud payload is rejected")
	for service in instances: service.queue_free()
	await process_frame
	var directory := DirAccess.open("user://")
	for file in directory.get_files():
		if file.begins_with(prefix.trim_prefix("user://")): directory.remove(file)
	print("CLOUD: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
