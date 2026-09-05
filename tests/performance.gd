extends SceneTree
func _initialize(): call_deferred("run")
func run():
	root.get_node("MobileCore").save = CoreSaveStore.new("user://benchmark-disposable.json")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.start_run()
	game.set_process(false)
	game.set_physics_process(false)
	var stress := "stress" in OS.get_cmdline_user_args()
	if stress:
		game.max_hp = 1000000
		game.hp = game.max_hp
		game.ranks = {"orbit":3,"burn":3,"frost":3,"chain":3,"nova":3}
		game.spawn_clock = 100000
	seed(42)
	for i in 48:
		game._spawn(Vector3(randf_range(-6,6),0,randf_range(-6,6)))
	for enemy in game.enemies:
		if stress: enemy.health = 1000000; enemy.max_health = 1000000
	for i in 60: await process_frame
	var samples: Array[float] = []
	var last := Time.get_ticks_usec()
	for i in 180:
		if stress:
			game._simulate(1.0/60.0)
			game.hud.update_stats()
		else:
			for enemy in game.enemies: enemy.animate(1.0/60.0,true)
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append(float(now-last)/1000.0)
		last=now
	samples.sort()
	var metrics := {"stress":stress,"median_frame_ms":samples[90],"p95_frame_ms":samples[171],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"enemies":game.enemies.size(),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT)}
	print(JSON.stringify(metrics))
	var file := FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"  "))
	file.close()
	game.queue_free()
	await create_timer(0.25).timeout
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute("user://benchmark-disposable.json" + suffix)
	quit()
