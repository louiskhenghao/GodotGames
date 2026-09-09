extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var core := root.get_node("MobileCore")
	var path := "user://account-ui-" + str(Time.get_ticks_msec()) + ".json"
	core.save = CoreSaveStore.new(path)
	var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.set_process(false); game.set_physics_process(false)
	game.hud.account_page()
	assert(game.hud.current_page == "account" and game.hud.screen.find_child("AccountPassword", true, false).secret, "account UI hides passwords")
	var next: Dictionary = core.save.data.duplicate(true)
	next.progress.selected_character = "zephyr"
	next.progress.unlocks = {"character:zephyr": true}
	assert(core.save.commit(next))
	game.stage = 8
	core.account.profile_loaded.emit()
	assert(game.player.character_id == "zephyr", "restoring another account refreshes the visible fighter")
	assert(game.stage == 0 and game.hud.current_page == "account", "restore respects venue unlocks and keeps the account page open")
	core.account.busy = true
	game.start_run()
	assert(game.mode == "home", "a fight cannot start while a cloud profile may replace the current one")
	core.account.busy = false
	game.go_home(); game.hud.home()
	assert(game.hud.screen.find_child("CloudStatus", true, false) != null, "home exposes local/cloud save state")
	game.start_run()
	assert(game.mode == "playing", "guest/offline play works without a backend session")
	game.queue_free(); await process_frame
	await create_timer(0.4).timeout
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(path + suffix)
	print("ACCOUNT UI: 6 checks, 0 failures")
	quit()
