extends SceneTree
func _initialize(): call_deferred("run")
func settle():
	for i in 12: await process_frame
func snap(id: String):
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://docs/account-preview/" + id + ".png")
func run():
	DirAccess.make_dir_recursive_absolute("res://docs/account-preview")
	var core := root.get_node("MobileCore")
	core.save = CoreSaveStore.new("user://account-capture-" + str(Time.get_ticks_msec()) + ".json")
	var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.set_process(false); game.set_physics_process(false)
	root.size = Vector2i(540, 960)
	game.hud.account_page(); await settle(); snap("login-540")
	root.size = Vector2i(320, 568)
	game.hud.account_page(); await settle(); snap("login-320")
	root.size = Vector2i(540, 960)
	core.account.user_id = "11111111-1111-4111-8111-111111111111"
	core.account.email = "player@example.test"
	core.account.verified = true
	core.account.status = "Two saves found · choose which to keep"
	core.save.data.coins = 850; core.save.data.progress.runs = 12
	var remote: Dictionary = core.save.defaults(); remote.coins = 1240; remote.progress.runs = 18
	core.account.conflict = {"kind": "conflict", "revision": "4", "remote": {"payload": remote, "revision": "4", "updatedAt": "2026-09-09T12:00:00Z"}}
	game.hud.account_page(); await settle(); snap("conflict")
	core.account.conflict.clear(); core.account.status = "Synced · progress safe in the cloud"
	game.hud.account_page(); await settle(); snap("signed-in")
	game.go_home(); game.hud.home(); await settle(); snap("home")
	var saved_path: String = core.account.guest_path
	game.queue_free(); await process_frame
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(saved_path + suffix)
	quit()
