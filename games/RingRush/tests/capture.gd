extends SceneTree
## Staged, deterministic actual-engine captures; isolated disposable profile.
var game: Node3D
func _initialize() -> void: call_deferred("capture")
func snap(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/preview-" + name + ".png")
func capture() -> void:
	seed(19)
	root.get_node("MobileCore").save = CoreSaveStore.new("user://capture-disposable.json")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await create_timer(0.4).timeout
	await snap("home")
	game.start_run()
	game.set_physics_process(false)
	game.elapsed = 51
	game.remaining = 39
	game.wave = 4
	game.level = 6
	game.hp = 82
	game.kills = 36
	game.run_coins = 108
	game.special_charge = 100
	game.ranks = {"burn":1,"chain":1,"orbit":2,"power":1,"speed":1}
	for i in 22:
		var angle := float(i)*TAU/22
		game._spawn(Vector3(cos(angle),0,sin(angle)) * randf_range(2.0,5.6),["rookie","runner","brute"][i%3])
	game.hud.playing()
	game._spawn(Vector3(0,0,-1),"rookie")
	game._attack()
	game._update_skills(0.02)
	game.vfx._process(0.05)
	game.hud.update_stats()
	await snap("gameplay")
	game.technique_id="quake"
	game.vfx.quake(game.player.position,Color("ffd182"),4.8)
	game.vfx._process(.22)
	await snap("earthquake")
	for i in range(1,5):
		game.stage=i
		game.arena.set_stage(i)
		for enemy in game.enemies: enemy.animate(.15,true)
		game.hud.playing()
		await snap("venue-"+str(i))
	game.xp=game.xp_needed
	game._level_up()
	await create_timer(0.22).timeout
	await snap("upgrade")
	game.go_home()
	game.hud.fighters()
	await create_timer(.22).timeout
	await snap("fighters")
	game.hud.moves()
	await create_timer(.22).timeout
	await snap("moves")
	game.hud.training()
	await create_timer(0.22).timeout
	await snap("training")
	game.hud.circuits()
	await create_timer(0.22).timeout
	await snap("circuits")
	game.hud.skills()
	await create_timer(0.22).timeout
	await snap("skills")
	game.hud.shop()
	await create_timer(0.22).timeout
	await snap("locker")
	for viewport in [Vector2i(540,800),Vector2i(540,1170),Vector2i(768,1024)]:
		root.size=viewport
		game.go_home()
		await create_timer(0.22).timeout
		await snap("home-%dx%d"%[viewport.x,viewport.y])
	game.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute("user://capture-disposable.json" + suffix)
	quit()
