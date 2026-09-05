extends SceneTree
var checks := 0
var failures := 0
var test_path := "user://ring_rush_test.json"

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func run() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(test_path + suffix)
	var store := CoreSaveStore.new(test_path)
	check(store.grant("first", 100), "reward commits")
	check(not store.grant("first", 100) and store.data.coins == 100, "duplicate reward is ignored")
	check(not store.grant("bad", -5), "negative grant rejected")
	check(not store.buy_upgrade("power", 101), "cannot overspend")
	check(store.buy_upgrade("power", 80) and store.data.coins == 20 and store.data.progress.power == 1, "upgrade and debit commit together")
	var reloaded := CoreSaveStore.new(test_path)
	reloaded.load_profile()
	check(reloaded.data.coins == 20 and reloaded.data.progress.power == 1, "profile survives restart")
	var broken := FileAccess.open(test_path, FileAccess.WRITE)
	broken.store_string("{broken")
	broken.close()
	reloaded.load_profile()
	check(reloaded.data.coins == 100, "corrupt save recovers previous complete backup")
	check(reloaded.grant("after-recovery",5), "can commit after recovering a backup")
	broken = FileAccess.open(test_path, FileAccess.WRITE)
	broken.store_string("broken again")
	broken.close()
	reloaded.load_profile()
	check(reloaded.data.coins == 100, "recovery commit preserves the healthy backup")
	broken = FileAccess.open(test_path, FileAccess.WRITE)
	broken.store_string('{"version":99}')
	broken.close()
	var future := CoreSaveStore.new(test_path)
	future.load_profile()
	check(not future.grant("unsafe-downgrade",5) and FileAccess.get_file_as_string(test_path).contains("99"), "future save version cannot be overwritten")
	var unwritable := CoreSaveStore.new("user://missing_directory/profile.json")
	check(not unwritable.grant("x", 9) and unwritable.data.coins == 0, "write failure leaves balance unchanged")
	var commerce := CoreCommerce.new()
	var provider := CoreCommerceProvider.new()
	root.add_child(commerce)
	commerce.configure(store, provider, RushBalance.PRODUCTS, RushBalance.REWARDS)
	commerce.reward("training_coins")
	check(store.data.coins == 20 and commerce.pending.is_empty(), "unconfigured provider cannot grant ads")
	var id := commerce._begin("ad", "training_coins")
	check(commerce._begin("ad", "training_coins").is_empty(), "concurrent requests are blocked")
	commerce._on_ad("unrelated", true, "")
	check(store.data.coins == 20, "unrelated callback ignored")
	commerce._on_ad(id, false, "cancelled")
	check(store.data.coins == 20, "cancelled ad grants nothing")
	id = commerce._begin("ad", "training_coins")
	commerce._on_ad(id, true, "")
	commerce._on_ad(id, true, "")
	check(store.data.coins == 80, "earned ad grants exactly once")
	id = commerce._begin("purchase", "gold_gloves")
	commerce._on_purchase(id, "gold_gloves", "tx-1", false, "unverified")
	check(not store.data.entitlements.has("gold_gloves"), "unverified purchase rejected")
	id = commerce._begin("purchase", "gold_gloves")
	commerce._on_purchase(id, "gold_gloves", "tx-1", true, "")
	check(store.data.entitlements.get("gold_gloves", false), "verified entitlement persists")
	id = commerce._begin("purchase", "gold_gloves")
	commerce._on_purchase(id, "gold_gloves", "tx-1", true, "")
	check(store.data.coins == 80, "replayed purchase cannot add currency")
	commerce.timeout_seconds = 0.02
	id = commerce._begin("ad", "training_coins")
	await create_timer(0.04).timeout
	commerce._on_ad(id, true, "late")
	check(commerce.pending.is_empty() and store.data.coins == 80, "timeout releases busy state and late ad grants nothing")
	id = commerce._begin("restore", "")
	commerce._on_restore(id, ["unknown", "gold_gloves"], true, "restored")
	check(not store.data.entitlements.has("unknown"), "restore filters unknown products")
	id = commerce._begin("purchase", "gold_gloves")
	await create_timer(0.04).timeout
	commerce._on_purchase(id, "gold_gloves", "late-paid-transaction", true, "")
	check(store.data.transactions.has("iap:late-paid-transaction"), "late verified purchase is reconciled after timeout")
	id = commerce._begin("restore", "")
	commerce._on_restore(id, [], false, "offline")
	check(commerce.pending.is_empty(), "failed restore releases busy state")
	commerce.queue_free()
	var core := root.get_node("MobileCore")
	core.save = CoreSaveStore.new("user://ring_rush_game_test.json")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	check(game.mode == "home" and game.enemy_pool.size() == 48 and game.enemies.is_empty(), "home scene loads")
	game.run_mode = "classic"
	game.start_run()
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = Vector2(100, 600)
	game.hud.stick._input(touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(200, 600)
	game.hud.stick._input(drag)
	check(is_equal_approx(game.hud.stick.vector.length(), 1), "touch stick clamps drag magnitude")
	var start_position: Vector3 = game.player.position
	game._simulate(0.04)
	check(game.player.position.distance_to(start_position) > 0, "touch input moves boxer in camera space")
	touch.pressed = false
	game.hud.stick._input(touch)
	check(game.hud.stick.vector == Vector2.ZERO, "touch release clears movement")
	game.player.position = Vector3.ZERO
	game._spawn(Vector3(0, 0, -1))
	game.damage = 100
	game._attack()
	check(game.kills == 1 and game.run_coins == 3 and game.pickups.size() == 1, "punch kills opponent and creates XP")
	game.pause_run()
	var before: float = game.elapsed
	game._simulate(0.04)
	check(game.elapsed == before and game.mode == "paused", "pause freezes run timer")
	game.resume_run()
	game.xp = game.xp_needed
	game._level_up()
	check(game.mode == "upgrade" and game.options.size() == 3, "level-up pauses for three choices")
	var old_damage: float = game.damage
	game.options = [RushBalance.ability("power")]
	game.choose_ability("power")
	check(game.mode == "playing" and game.damage > old_damage, "ability changes combat and resumes")
	game.max_hp = 100000
	game.hp = 100000
	game.damage = 1000
	game.reach = 20
	for i in 2800:
		if game.mode == "upgrade": game.choose_ability(game.options[0].id)
		if game.mode == "playing": game._simulate(1.0 / 30.0)
		if i % 30 == 0: await process_frame
	check(game.mode == "result" and game.wave >= 6 and game.remaining == 0, "complete 90-second run reaches victory")
	check(game.boss_defeated and core.save.data.progress.unlocked_stage == 1, "champion defeat unlocks next circuit")
	var balance: int = core.save.data.coins
	game.finish_run(true)
	check(core.save.data.coins == balance and balance > 0, "run reward cannot settle twice")
	check(game.enemies.size() <= RushBalance.MAX_ENEMIES and game.pickups.size() <= 64, "crowd and pickup counts remain bounded")
	game.start_run()
	game.hp = 0
	game._simulate(0.02)
	check(game.mode == "defeat", "zero health offers an optional revive")
	game.finish_run(false)
	await expanded_checks(game, core)
	game.queue_free()
	await process_frame
	# Allow the audio mixer to release stopped playback objects.
	await create_timer(0.25).timeout
	for path in [test_path, "user://ring_rush_game_test.json"]:
		for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(path + suffix)
	print("\n%d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func expanded_checks(game: Node3D, core: Node) -> void:
	game.go_home()
	game.select_stage(2)
	check(game.stage == 0, "locked circuit cannot be selected")
	game.select_stage(1)
	check(game.stage == 1, "unlocked circuit can be selected")
	game.start_run()
	game.set_physics_process(false)
	game.spawn_clock = 1000
	game.dash()
	var cooldown: float = game.dash_clock
	game.dash()
	check(game.dash_time > 0 and game.dash_clock == cooldown, "dash has cooldown and invulnerability")
	var hp: float = game.hp
	game._take_damage(10)
	check(game.hp == hp, "dash evades incoming damage")
	game.dash_time = 0
	game.invulnerable = 0
	game.ranks.armor = 2
	game._take_damage(10)
	check(is_equal_approx(game.hp, hp-8), "armor reduces incoming damage")
	game._take_damage(10)
	check(is_equal_approx(game.hp, hp-8), "swarm hits share a short invulnerability window")
	game.invulnerable = 0
	game.ranks.regen = 1
	game._simulate(0.5)
	check(game.hp > hp-8, "regeneration restores health")
	game._clear_combat()
	var enemy = game._spawn(Vector3(0,0,-1), "rookie")
	game.damage = 5
	game.ranks.burn = 2
	game.ranks.frost = 1
	game._hit(enemy,5)
	check(enemy.burn == 3 and enemy.frost > 0, "punch applies fire and frost status")
	var before: float = enemy.health
	game._build_neighbors()
	game._update_enemy(enemy,0.1)
	check(enemy.health < before, "burn damage ticks independently of punches")
	game.ranks.leech = 2
	game.hp = 50
	game._hit(enemy,1000)
	check(game.hp == 52, "knockout restores health with Fighting spirit")
	game._update_knockouts(2.0) # Recycle after the new visible fall completes.
	var pooled_id: int = enemy.get_instance_id()
	var recycled = game._spawn(Vector3(0,0,-1), "brute")
	check(recycled.get_instance_id() == pooled_id and recycled.burn == 0 and recycled.frost == 0, "reused actor resets status effects")
	check(recycled.role == "brute" and recycled.max_health > 60, "brute has distinct stats")
	game.technique_id = "quake"
	game.special_charge = 99
	before = recycled.health
	game.special()
	check(recycled.health == before, "special cannot fire before fully charged")
	game.special_charge = 100
	game.damage = 20
	game.special()
	check(recycled.health < before and game.special_charge < 100, "charged special deals area damage and spends meter")
	game._clear_combat()
	game.ranks = {"orbit":1}
	enemy = game._spawn(Vector3(1.8,0,0),"rookie")
	game.elapsed = 0
	game.orbit_clock = 0
	before = enemy.health
	game._update_skills(0.01)
	check(enemy.health < before, "orbiting gloves deal contact damage")
	game._clear_combat()
	game.ranks = {"chain":1}
	game.reach = 2
	game.damage = 5
	game._spawn(Vector3(0,0,-1),"rookie")
	var chained = game._spawn(Vector3(0,0,-2.8),"rookie")
	before = chained.health
	game._attack()
	check(chained.health < before, "lightning chains beyond the direct punch reach")
	game.xp = game.xp_needed
	game._level_up()
	var previous_ranks: Dictionary = game.ranks.duplicate()
	game.choose_ability("nonexistent")
	check(game.mode == "upgrade" and game.ranks == previous_ranks, "unoffered skill cannot mutate a build")
	game.rerolls = 1
	game.reroll()
	var rolled: Array = game.options.duplicate()
	game.reroll()
	check(game.rerolls == 0 and game.options == rolled, "one reroll per run")
	var maxed := {}
	for entry in RushBalance.ABILITIES: maxed[entry.id] = entry.max
	check(RushBalance.choices(maxed,false).is_empty(), "maxed skills and unnecessary heal are excluded")
	game.choose_ability(game.options[0].id)
	game._clear_combat()
	game.ranks.clear()
	game.elapsed = 89.99
	game.boss_spawned = false
	game.boss_defeated = false
	game._simulate(0.02)
	check(game.mode == "playing" and game.boss.active, "timer ending with champion alive enters overtime")
	game.elapsed = 119.99
	game._simulate(0.02)
	check(game.mode == "result" and not game.result_won, "overtime has a bounded defeat deadline")
	var initial: int = core.save.data.coins
	check(RushProgress.checkpoint(core.save,"interrupted-test",21,0,7), "interrupted round checkpoint commits")
	check(RushProgress.recover(core.save)==21 and core.save.data.coins==initial+21, "checkpoint recovery banks earned coins")
	check(RushProgress.recover(core.save)==0 and core.save.data.coins==initial+21, "checkpoint cannot recover twice")
	game.go_home()
	var a: Mesh = game.enemy_pool[0].crowd_library.clips.Idle[0]
	var b: Mesh = game.enemy_pool[1].crowd_library.clips.Idle[0]
	check(a == b and a.get_surface_count()==2, "crowds share the actual two-surface humanoid pose meshes")
	game.start_run()
	game.set_physics_process(false)
	await process_frame
	await process_frame
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.index = 0
	touch.position = Vector2(100,500)
	game.hud.stick._input(touch)
	var second := InputEventScreenTouch.new()
	second.pressed = true
	second.index = 1
	second.position = game.hud.dash_button.get_global_rect().get_center()
	game.hud._input(second)
	check(game.dash_clock > 0 and game.hud.stick.finger == 0, "second touch activates dash without stealing steering")
	game.hud.stick.reset()
	game.hud.stick._input(second)
	check(game.hud.stick.finger == -1, "touching skill button does not start the movement stick")
	game.pause_run()
	check(game.hud.stick.vector == Vector2.ZERO, "pause clears held touch input")
	# Every menu must build successfully with real callbacks and scroll containers.
	game.hud.skills()
	game.hud.settings()
	game.go_home()
	game.hud.training()
	game.hud.circuits()
	game.hud.shop()
	check(game.hud.current_page == "shop", "all expanded menus construct without errors")
