extends SceneTree
func _initialize(): call_deferred("run")
func run():
	seed(710)
	root.get_node("MobileCore").save=CoreSaveStore.new("user://balance-bot.json")
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	if not OS.get_cmdline_user_args().is_empty(): game.run_mode=OS.get_cmdline_user_args()[0]
	game.start_run()
	var steps := 0
	while game.mode != "result" and steps<72000:
		if game.mode=="upgrade":
			var choice: String=game.options[0].id
			for entry in game.options:
				if entry.id in ["power","speed","orbit","chain","heal","regen"]:choice=entry.id;break
			game.choose_ability(choice)
		var nearest: RushBoxer
		var distance := 100.0
		for enemy in game.enemies:
			var d: float=enemy.position.distance_to(game.player.position)
			if d<distance:distance=d;nearest=enemy
		var motion := Vector3.ZERO
		if nearest != null:
			var offset: Vector3=nearest.position-game.player.position
			if nearest.windup>0 and distance<(2.8 if nearest.role=="boss" else 1.5):motion=-offset.normalized()
			elif distance>1.7:motion=offset.normalized()
			if distance<3.2:
				game.technique()
				game.special()
		game.hud.stick.vector=Vector2((motion.x-motion.z)/sqrt(2),(motion.x+motion.z)/sqrt(2))
		game._simulate(1.0/30)
		steps+=1
		if steps%300==0:await process_frame
	print("BALANCE BOT: ",JSON.stringify({"mode":game.mode,"won":game.result_won,"wave":game.wave,"seconds":game.elapsed,"hp":game.hp,"kills":game.kills,"level":game.level,"coins":game.run_coins,"build":game.ranks}))
	game.queue_free()
	await process_frame
	await create_timer(.25).timeout
	for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://balance-bot.json"+suffix)
	quit()
