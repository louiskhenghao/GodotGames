extends SceneTree
## Opt-in real HTTP test. Requires a verified disposable account, never production data.
var failed := false
var prefix := "user://cloud-http-" + Crypto.new().generate_random_bytes(6).hex_encode()
func _initialize(): call_deferred("run")
func check(value: bool, description: String) -> void:
	if not value: failed = true; push_error(description)
func client(suffix: String) -> CoreAccountSync:
	var account := CoreAccountSync.new(); root.add_child(account)
	account.configure(CoreSaveStore.new(prefix + suffix + ".json"), "ringrush", OS.get_environment("CLOUD_TEST_URL"), func(): return true)
	account.set_process(false)
	return account
func run():
	if not OS.get_environment("CLOUD_TEST_URL").begins_with("http://127.0.0.1:") or not OS.get_environment("CLOUD_TEST_EMAIL").ends_with("@example.test"):
		push_error("Requires a disposable localhost API and example.test account"); quit(1); return
	var a := client("a")
	a.store.grant(prefix + "guest-run", 140)
	await a.login(OS.get_environment("CLOUD_TEST_EMAIL"), OS.get_environment("CLOUD_TEST_PASSWORD"))
	check(a.verified, "Godot authenticates against the real API: " + a.status)
	if not a.verified: quit(1); return
	if a.conflict.get("kind") == "first": await a.resolve("guest")
	check(a.status.begins_with("Synced"), "Godot completes first cloud upload: " + a.status)
	var expected := int(a.store.data.coins)
	var b := client("b")
	await b.login(OS.get_environment("CLOUD_TEST_EMAIL"), OS.get_environment("CLOUD_TEST_PASSWORD"))
	check(b.store.data.coins == expected and b.conflict.is_empty(), "Second game instance restores the account")
	a.store.grant(prefix + "offline-reward", 33)
	var valid_url := a.api.base_url
	a.api.base_url = "http://127.0.0.1:1"
	await a.sync_now()
	check(a.store.data.coins == expected + 33 and a.status.begins_with("Offline"), "HTTP network failure preserves local progress")
	a.api.base_url = valid_url
	await a.sync_now()
	await b.sync_now()
	check(b.store.data.coins == expected + 33, "Reconnection uploads and propagates the offline reward: " + a.status + " / " + b.status)
	a.store.grant(prefix + "conflict-a", 17)
	b.store.grant(prefix + "conflict-b", 29)
	await a.sync_now()
	await b.sync_now()
	check(b.conflict.get("kind") == "conflict", "Real backend revisions detect two-device divergence: " + b.status)
	await b.resolve("cloud")
	check(b.store.data.coins == expected + 50, "Explicit conflict choice loads the selected cloud progress")
	await a.logout()
	check(a.user_id.is_empty() and a.store.data.coins == 140, "Sign out restores the separate guest profile")
	a.queue_free(); b.queue_free()
	await process_frame
	var directory := DirAccess.open("user://")
	for file in directory.get_files():
		if file.begins_with(prefix.trim_prefix("user://")): directory.remove(file)
	print("REAL CLOUD API: ", "FAIL" if failed else "PASS", " (login, import, two devices, offline/reconnect, conflict, logout)")
	quit(1 if failed else 0)
