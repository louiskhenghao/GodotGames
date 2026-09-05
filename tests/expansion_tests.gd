extends SceneTree
var failures := 0
var checks := 0
func _initialize(): call_deferred("run")
func check(value: bool, description: String):
	checks+=1
	if not value: failures+=1; push_error(description)
	else: print("PASS: "+description)
func run():
	var core := root.get_node("MobileCore")
	core.save=CoreSaveStore.new("user://expansion-test.json")
	check(not RushRoster.unlock(core.save,"character","titan"),"insufficient coins cannot unlock fighter")
	check(not RushRoster.unlock(core.save,"character","forged"),"unknown catalog ID is rejected")
	check(not RushRoster.equip(core.save,"move","meteor"),"locked technique cannot be equipped")
	core.save.grant("test-coins",5000)
	for c in RushRoster.CHARACTERS:
		check(RushRoster.unlock(core.save,"character",c.id),"unlock "+c.id)
		var coins: int=core.save.data.coins
		check(RushRoster.unlock(core.save,"character",c.id) and coins==core.save.data.coins,"duplicate unlock does not debit "+c.id)
		check(RushRoster.owned(core.save,"move",c.move),"signature move included for "+c.id)
	core.save.load_profile()
	check(RushRoster.owned(core.save,"character","sol"),"fighter ownership survives disk reload")
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	await process_frame
	for c in RushRoster.CHARACTERS:
		RushRoster.equip(core.save,"character",c.id)
		game.go_home()
		game.run_mode="sprint"
		game.start_run()
		check(game.max_hp==c.hp and game.damage==c.damage and game.technique_id==c.move,"distinct starting kit "+c.id)
		game.finish_run(false)
	for m in RushRoster.MOVES:
		game.go_home()
		game.start_run()
		game.technique_id=m.id
		game.player.rotation.y=0
		var target=game._spawn(Vector3(0,0,-1.2),"boss")
		var hp: float=target.health
		game.technique()
		var cd: float=game.technique_clock
		game.technique()
		check(game.technique_clock==cd and cd>0,"cooldown blocks repeated "+m.id)
		for i in 12: game._update_technique(.1)
		check(target.health<hp,"technique damages target: "+m.id)
		game.finish_run(false)
	for id in ["sprint","survival30","onslaught50","ladder","hell","blitz","bossrush"]:
		game.go_home()
		game.run_mode=id
		game.start_run()
		game.hp=1000000
		game.max_hp=1000000
		game.damage=10000
		game.reach=30
		var frames := 0
		var visited := {}
		while game.mode != "result" and frames<30000:
			if game.mode=="upgrade": game.choose_ability(game.options[0].id)
			game._simulate(.1)
			visited[game.stage]=true
			frames+=1
			if frames%200==0: await process_frame
		check(game.result_won and game.completed_waves==RushWaveDirector.mode_info(id).waves,"finite clear-based completion: "+id)
		check(core.save.data.progress.get("best_wave_"+id,0)==game.completed_waves,"mode record stored: "+id)
		var balance: int=core.save.data.coins
		game.finish_run(true)
		check(balance==core.save.data.coins,"result cannot pay twice: "+id)
		if id=="ladder":check(visited.size()==5,"ladder traverses all five venues")
	game.go_home()
	game.run_mode="survival30"
	game.start_run()
	game.director.number=17
	game.wave=17
	game.director.spawned=3
	game.kills=99
	game.run_coins=327
	game.hp=63
	game.ranks={"burn":2,"chain":1}
	var opponent=game._spawn(Vector3(2,0,-1),"brute")
	opponent.health=23
	opponent.burn=2
	game.checkpoint()
	var run_id: String=game.run_id
	var balance: int=core.save.data.coins
	core.save.load_profile()
	game.go_home()
	check(game.has_resume(),"serialized long-run snapshot is offered for resume")
	game.resume_saved_run()
	check(game.mode=="paused" and game.run_id==run_id and game.wave==17 and game.hp==63,"resume restores exact run, wave and health, initially paused")
	check(game.enemies.size()==1 and game.enemies[0].health==23 and game.enemies[0].burn==2,"resume restores remaining enemy and status")
	check(game.run_coins==327 and core.save.data.coins==balance and game.rank_of("burn")==2,"resume retains build without prematurely paying coins")
	game.finish_run(false)
	check(core.save.data.coins==balance+327,"resumed run settles once")
	check(not RushRunSnapshot.valid({"version":1}),"incomplete resume snapshot rejected")
	game.go_home()
	game.hud.fighters()
	game.hud.moves()
	game.hud.circuits()
	check(game.hud.current_page=="circuits","expanded character, move and mode screens build")
	game.queue_free()
	await process_frame
	await create_timer(.25).timeout
	for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://expansion-test.json"+suffix)
	print("EXPANSION: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
