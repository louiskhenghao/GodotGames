extends Node3D
const HIT_SOUND = preload("res://assets/punch.wav")
const LEVEL_SOUND = preload("res://assets/level.wav")
var arena: RushArena
var player: RushBoxer
var enemies: Array[RushBoxer] = []
var enemy_pool: Array[RushBoxer] = []
var pickups: Array[MeshInstance3D] = []
var pickup_pool: Array[MeshInstance3D] = []
var orbiters: Array[MeshInstance3D] = []
var vfx: CoreImpactPool
var audio: CoreAudioPool
var hud: RushHUD
var camera: Camera3D
var podium: Node3D
var camera_home := Vector3(16, 22, 16)
var follow_camera:=RushFollowCamera.new()
var knockouts:Array[RushBoxer]=[]
var impact_voice_clock:=0.0
var mode := "home"
var stage := 0
var queued_replay:=false
var revive_used:=false
var restoring := false
var run_mode := "sprint"
var director := RushWaveDirector.new()
var technique_clock := 0.0
var cyclone_clock := 0.0
var cyclone_tick := 0.0
var projectile_time := 0.0
var projectile_position := Vector3.ZERO
var projectile_direction := Vector3.ZERO
var projectile_hits: Array[int] = []
var skill_multiplier := 1.0
var barrage_time := 0.0
var barrage_tick := 0.0
var hit_stop := 0.0
var completed_waves := 0
var music: AudioStreamPlayer
var technique_id := "quake"
var hp := 100.0
var max_hp := 100.0
var damage := 18.0
var reach := 2.0
var move_speed := 4.3
var cooldown := 0.65
var attack_clock := 0.0
var spawn_clock := 0.0
var elapsed := 0.0
var remaining := 90.0
var wave := 1
var kills := 0
var run_coins := 0
var level := 1
var xp := 0
var xp_needed := 5
var nova := false
var nova_clock := 0.0
var orbit_clock := 0.0
var run_id := ""
var shake := 0.0
var options: Array = []
var ranks: Dictionary = {}
var rerolls := 1
var dash_clock := 0.0
var dash_time := 0.0
var dash_direction := Vector3.ZERO
var invulnerable := 0.0
var special_charge := 0.0
var combo := 0
var combo_clock := 0.0
var boss: RushBoxer
var boss_spawned := false
var boss_defeated := false
var result_won := false
var checkpoint_clock := 15.0
var neighbor_grid: Dictionary = {}

func _ready() -> void:
	MobileCore.configure_commerce(RushBalance.PRODUCTS, RushBalance.REWARDS)
	arena = RushArena.new()
	add_child(arena)
	camera = Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.current = true
	vfx = CoreImpactPool.new()
	add_child(vfx)
	audio = CoreAudioPool.new()
	add_child(audio)
	music = AudioStreamPlayer.new()
	add_child(music)
	music.volume_db = -15
	player = RushBoxer.new()
	add_child(player)
	player.build(true)
	# Preallocate actors and pickups. Combat never constructs or frees a fighter.
	for i in RushBalance.MAX_ENEMIES:
		var enemy := RushBoxer.new()
		add_child(enemy)
		enemy.build(false)
		enemy.active = false
		enemy.visible = false
		enemy_pool.append(enemy)
	var gem := SphereMesh.new()
	gem.radius = 0.12
	gem.height = 0.24
	gem.radial_segments = 6
	gem.rings = 3
	gem.material = RushBoxer.material(Color("4bf6cf"))
	gem.material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 64:
		var pickup := MeshInstance3D.new()
		pickup.mesh = gem
		pickup.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pickup.visible = false
		add_child(pickup)
		pickup_pool.append(pickup)
	for i in 3:
		var glove := RushBoxer.sphere(self, 0.23, Vector3.ZERO, Color("e8b853"))
		glove.visible = false
		orbiters.append(glove)
	_build_podium()
	hud = RushHUD.new()
	hud.game = self
	add_child(hud)
	apply_settings()
	MobileCore.commerce.reward_ready.connect(_claim_ad_reward)
	MobileCore.commerce.completed.connect(_commerce_transition)
	for receipt_id in MobileCore.save.data.get("reward_receipts",{}).keys(): _claim_ad_reward(receipt_id)
	var recovered := 0 if has_resume() else RushProgress.recover(MobileCore.save)
	go_home()
	if MobileCore.save.unsupported_version: hud.toast("This save needs a newer game version. Progress is read-only.")
	elif recovered > 0: hud.toast("Recovered %d coins from your interrupted run." % recovered)
	elif recovered < 0: hud.toast("Storage unavailable. Your previous reward is waiting to be saved.")
	get_tree().auto_accept_quit = false
	get_viewport().size_changed.connect(_frame_showroom)

func _build_podium() -> void:
	podium = Node3D.new()
	add_child(podium)
	var base := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.65
	mesh.bottom_radius = 1.85
	mesh.height = 0.30
	mesh.radial_segments = 64
	base.mesh = mesh
	base.material_override = RushBoxer.material(Color("122b3a"))
	base.position.y = -0.15
	podium.add_child(base)
	var trim := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 1.66
	ring.outer_radius = 1.70
	ring.rings = 64
	ring.ring_segments = 6
	trim.mesh = ring
	trim.material_override = RushBoxer.material(Color("43e4ca"))
	trim.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trim.position.y = -0.05
	podium.add_child(trim)

func apply_settings() -> void:
	vfx.enabled = MobileCore.save.data.settings.get("effects", true)
	audio.enabled = MobileCore.save.data.settings.get("sound", true)
	if music != null: music.volume_db = -15 if MobileCore.save.data.settings.get("music",true) else -80
	var low: bool = MobileCore.save.data.settings.get("low_quality", false)
	arena.set_quality(low)
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if low else Viewport.MSAA_2X
	if not vfx.enabled: vfx.clear()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if mode in ["playing","paused","upgrade","defeat"]:
			checkpoint()
			if mode == "playing": pause_run()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if mode in ["playing", "paused", "upgrade", "defeat"]: checkpoint()
		get_tree().quit()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE:
		if mode == "playing": pause_run()
		elif mode == "paused": resume_run()
	elif event.keycode == KEY_SPACE: dash()
	elif event.keycode == KEY_E: special()
	elif event.keycode == KEY_Q: technique()

func _clear_combat() -> void:
	for enemy in enemy_pool:
		enemy.active=false
		enemy.finish_defeat()
	knockouts.clear()
	for pickup in pickups: pickup.visible = false
	for glove in orbiters: glove.visible = false
	enemies.clear()
	pickups.clear()
	boss = null
	cyclone_clock = 0
	barrage_time = 0
	projectile_time = 0
	hit_stop = 0
	vfx.clear()

func go_home() -> void:
	mode = "home"
	_clear_combat()
	player.set_character(selected_character().id)
	technique_id = selected_move()
	player.position = Vector3.ZERO
	player.scale *= 1.9
	player.face(Vector3(0.6, 0, 1))
	player.set_gold(MobileCore.save.data.entitlements.get("gold_gloves", false))
	podium.visible = true
	arena.showroom(true)
	# Lights and environment still affect the showroom while arena geometry is hidden.
	camera.position = Vector3(5, 3.7, 8)
	camera.look_at(Vector3(0, 1.75, 0))
	camera.position -= camera.basis.y * 1.30
	hud.current_page="home"
	_frame_showroom()
	_play_music("menu")
	hud.home()

func select_stage(index: int) -> void:
	var unlocked := clampi(int(MobileCore.save.data.progress.get("unlocked_stage", 0)), 0, 4)
	if mode != "home" or index < 0 or index > unlocked: return
	stage = index
	hud.home()

func start_run() -> void:
	if has_resume() and not restoring:
		hud.toast("Resume your saved fight, or bank it from the challenge menu.")
		return
	if MobileCore.save.unsupported_version:
		hud.toast("Update the game to use this newer save. Your file has been preserved.")
		return
	if mode not in ["home", "result"] or not MobileCore.commerce.pending.is_empty(): return
	if run_mode == "ladder": stage = 0
	if stage > int(MobileCore.save.data.progress.get("unlocked_stage", 0)): return
	if mode == "result" and not MobileCore.save.data.transactions.has(run_id): return
	if not restoring and MobileCore.save.data.progress.has("pending_run") and RushProgress.recover(MobileCore.save) < 0:
		hud.toast("Save your previous reward first. Free storage and try again.")
		return
	_clear_combat()
	mode = "playing"
	arena.showroom(false)
	arena.set_stage(stage)
	podium.visible = false
	camera.position = camera_home
	camera.look_at(Vector3.ZERO)
	camera.size = 24.0 if stage in [1,3] else 21.5
	var fighter := selected_character()
	player.set_character(fighter.id)
	technique_id = selected_move()
	max_hp = fighter.hp + int(MobileCore.save.data.progress.get("health", 0)) * 10
	hp = max_hp
	damage = fighter.damage + int(MobileCore.save.data.progress.get("power", 0)) * 3
	reach = 2.0
	move_speed = fighter.speed
	cooldown = fighter.tempo
	attack_clock = 0
	spawn_clock = 0.2
	elapsed = 0
	remaining = RushBalance.ROUND_SECONDS
	wave = 1
	kills = 0
	run_coins = 0
	level = 1
	xp = 0
	xp_needed = 5
	nova = false
	nova_clock = 3
	orbit_clock = 0
	shake = 0
	ranks.clear()
	ranks[fighter.rank] = 2 if fighter.id == "titan" else 1
	if fighter.rank == "feet": move_speed *= 1.12
	rerolls = 2
	technique_clock = 0
	completed_waves = 0
	revive_used=false
	director.begin(run_mode)
	dash_clock = 0
	dash_time = 0
	invulnerable = 0
	special_charge = minf(100, 35 + int(MobileCore.save.data.progress.get("charge", 0)) * 10)
	combo = 0
	combo_clock = 0
	boss_spawned = false
	boss_defeated = false
	result_won = false
	checkpoint_clock = 15
	run_id = "run:" + Crypto.new().generate_random_bytes(16).hex_encode()
	player.position = Vector3.ZERO
	_reset_combat_camera()
	player.set_gold(MobileCore.save.data.entitlements.get("gold_gloves", false))
	_play_music("fight" if stage != 1 else "street")
	if not restoring: checkpoint()
	hud.playing()

func checkpoint() -> bool:
	if run_id.is_empty():return false
	var saved:=RushProgress.checkpoint(MobileCore.save,run_id,run_coins,stage,kills,RushRunSnapshot.capture(self))
	if not saved:hud.toast("Could not save. Free storage and retry.")
	return saved

func pause_run() -> void:
	if mode != "playing": return
	mode = "paused"
	hud.paused()

func resume_run() -> void:
	if mode not in ["paused", "upgrade"]: return
	mode = "playing"
	hud.playing()

func finish_run(won: bool) -> void:
	if mode not in ["playing", "paused", "result","defeat"]: return
	if mode != "result":
		result_won = won
		if won: run_coins += int(RushBalance.STAGES[stage].reward)
	mode = "result"
	var saved := RushProgress.settle(MobileCore.save, run_id, run_coins, stage, kills, result_won, run_mode, completed_waves)
	hud.result(result_won, saved)

func _process(delta: float) -> void:
	if mode in ["playing","home"]:player.animate(delta, mode == "playing" and _movement().length_squared() > 0.01)
	if mode == "home":
		if hud.current_page=="move_demo": _update_technique(delta)
	elif mode == "playing":
		shake = maxf(0, shake - delta)
		follow_camera.update(camera,player.position,get_viewport().get_visible_rect().size,delta,false,shake if vfx.enabled and not MobileCore.save.data.settings.get("reduced_motion",false) else 0.0)
		hud.update_stats()

func _physics_process(delta: float) -> void:
	_simulate(delta)

func _simulate(delta: float) -> void:
	if mode != "playing": return
	_update_knockouts(delta)
	impact_voice_clock=maxf(0,impact_voice_clock-delta)
	if hp <= 0:
		_knockout()
		return
	if hit_stop > 0:
		hit_stop = maxf(0,hit_stop-delta)
		return
	elapsed += delta
	if run_mode == "classic":
		remaining = maxf(0, RushBalance.ROUND_SECONDS - elapsed)
		wave = mini(6, 1 + int(elapsed / 15))
	else:
		wave = director.number
		remaining = elapsed
		if _advance_waves(delta): return
	technique_clock = maxf(0,technique_clock-delta)
	invulnerable = maxf(0, invulnerable - delta)
	dash_clock = maxf(0, dash_clock - delta)
	dash_time = maxf(0, dash_time - delta)
	combo_clock -= delta
	if combo_clock <= 0: combo = 0
	hp = minf(max_hp, hp + rank_of("regen") * delta)
	special_charge = minf(100, special_charge + delta * 0.7 * (1 + rank_of("fury") * 0.25))
	checkpoint_clock -= delta
	if checkpoint_clock <= 0:
		checkpoint_clock = 15
		checkpoint()
	if run_mode == "classic":
		if elapsed >= 75 and not boss_spawned: _spawn_boss()
		if remaining <= 0 and boss_defeated:
			completed_waves = 6
			finish_run(true)
			return
		if elapsed >= 120:
			finish_run(false)
			return
	var movement := dash_direction if dash_time > 0 else _movement()
	player.position = RushArenaLayout.move(player.position,movement*(16 if dash_time>0 else move_speed)*delta,stage)
	if movement.length_squared() > 0.01: player.face(movement)
	spawn_clock -= delta
	if spawn_clock <= 0:
		if run_mode == "classic" and elapsed < 90:
			spawn_clock = maxf(.40,1.1-wave*.11) / float(RushBalance.STAGES[stage].difficulty)
			if enemies.size() < RushBalance.MAX_ENEMIES-(0 if boss_spawned else 1):
				var angle := randf()*TAU
				_spawn(RushArenaLayout.spawn_point(stage,angle))
		elif run_mode != "classic" and not director.clearing and director.spawned < director.quota:
			spawn_clock = maxf(.24,.65-wave*.008)
			if director.boss_wave() and director.spawned == 0: _spawn_boss()
			else:
				var angle := randf()*TAU
				var kind := "runner" if wave%3 == 1 and director.spawned%3 == 0 else ("brute" if wave%3 == 2 and director.spawned%4 == 0 else "rookie")
				_spawn(RushArenaLayout.spawn_point(stage,angle),kind)
			director.spawned += 1
	if arena.update_hazards(elapsed):
		for vent in arena.vents:
			if player.position.distance_to(vent.position) < 1.18: _take_damage(12)
		if int(elapsed*8)%3 == 0:
			for vent in arena.vents: vfx.burst(vent.position,Color("ffc58e"),2,.7)
	attack_clock -= delta
	if attack_clock <= 0: _attack()
	_build_neighbors()
	for enemy: RushBoxer in enemies.duplicate():
		if enemy.active: _update_enemy(enemy, delta)
	if hp <= 0:
		_knockout()
		return
	_update_skills(delta)
	for pickup: MeshInstance3D in pickups.duplicate():
		pickup.rotate_y(delta * 3)
		var distance := pickup.position.distance_to(player.position)
		if distance < 2.5 + rank_of("magnet") * 1.2:
			pickup.position = pickup.position.move_toward(player.position + Vector3.UP * 0.3, delta * 8)
		if distance < 0.65:
			pickups.erase(pickup)
			pickup.visible = false
			xp += 1
	if xp >= xp_needed: _level_up()

func _build_neighbors() -> void:
	neighbor_grid.clear()
	for enemy in enemies:
		var key := Vector2i(floori(enemy.position.x / 1.2), floori(enemy.position.z / 1.2))
		if not neighbor_grid.has(key): neighbor_grid[key] = []
		neighbor_grid[key].append(enemy)

func _update_enemy(enemy: RushBoxer, delta: float) -> void:
	var start_position:=enemy.position
	enemy.burn = maxf(0, enemy.burn - delta)
	enemy.frost = maxf(0, enemy.frost - delta)
	enemy.dot_clock -= delta
	if enemy.burn > 0 and enemy.dot_clock <= 0:
		enemy.dot_clock = 0.5
		_hit(enemy, enemy.burn_damage * 0.5, false, false)
		vfx.burst(enemy.position + Vector3.UP, Color("ff934b"), 3)
		if not enemy.active: return
	if enemy.launch_time > 0:
		enemy.position += enemy.knockback*delta
		enemy.knockback=enemy.knockback.move_toward(Vector3.ZERO,delta*20)
		enemy.position=RushArenaLayout.move(start_position,enemy.position-start_position,stage,.33*enemy.scale.x)
		enemy.animate(delta,false)
		return
	var direction := player.position - enemy.position
	var distance := direction.length()
	enemy.face(direction)
	var slow := 0.65 if enemy.frost > 0 else 1.0
	if enemy.windup > 0:
		enemy.windup -= delta * slow
		var radius := 2.5 if enemy.role == "boss" else 1.05
		enemy.warning.visible = true
		var size := radius / enemy.scale.x
		enemy.warning.scale = Vector3(size, 0.08, size)
		if enemy.windup <= 0:
			enemy.warning.visible = false
			enemy.punch()
			enemy.attack_timer = 3.3 if enemy.role == "boss" else 1.0
			if distance < radius: _take_damage(22 if enemy.role == "boss" else (10 if enemy.role == "brute" else 6))
			if enemy.role == "boss": vfx.ring(enemy.position, Color("ff6f5a"), radius)
	else:
		enemy.attack_timer -= delta * slow
		var separation := Vector3.ZERO
		var cell := Vector2i(floori(enemy.position.x / 1.2), floori(enemy.position.z / 1.2))
		for x in range(-1, 2):
			for y in range(-1, 2):
				for other: RushBoxer in neighbor_grid.get(cell + Vector2i(x, y), []):
					var away := enemy.position - other.position
					if away.length_squared() < 0.81 and away.length_squared() > 0.001: separation += away.normalized() * 0.8
		if distance > 0.9: enemy.position += (RushArenaLayout.steer(enemy.position,player.position,stage) * enemy.speed * slow + separation) * delta
		if distance < (2.3 if enemy.role == "boss" else 1.1) and enemy.attack_timer <= 0:
			enemy.windup = 0.9 if enemy.role == "boss" else 0.32
	enemy.position += enemy.knockback * delta
	enemy.knockback = enemy.knockback.move_toward(Vector3.ZERO, delta * 20)
	enemy.position=RushArenaLayout.move(start_position,enemy.position-start_position,stage,.33*enemy.scale.x)
	enemy.animate(delta, distance > 0.9 and enemy.windup <= 0)

func _take_damage(amount: float) -> void:
	if invulnerable > 0 or hp <= 0: return
	hp = maxf(0, hp - amount * (1 - rank_of("armor") * 0.1))
	invulnerable = 0.45
	player.hurt(vfx.enabled)
	audio.play(load("res://assets/hurt.wav"),randf_range(.94,1.05))
	hud.flash_damage()
	shake = 0.14
	combo = 0
	vfx.burst(player.position + Vector3.UP, Color("ff6e63"), 8)
	haptic(20)

func _update_skills(delta: float) -> void:
	_update_technique(delta)
	nova_clock -= delta
	if rank_of("nova") > 0 and nova_clock <= 0:
		nova_clock = 6
		vfx.ring(player.position, Color("49e0bf"), 3.8)
		_area_hit(3.8, damage * (0.8 + rank_of("nova") * 0.4))
	orbit_clock -= delta
	for i in 3:
		orbiters[i].visible = i < rank_of("orbit")
		var angle := elapsed * 2.5 + i * TAU / maxi(1, rank_of("orbit"))
		orbiters[i].position = player.position + Vector3(cos(angle) * 1.8, 0.75, sin(angle) * 1.8)
	if orbit_clock <= 0 and rank_of("orbit") > 0:
		orbit_clock = 0.4
		for enemy: RushBoxer in enemies.duplicate():
			for i in rank_of("orbit"):
				if enemy.active and enemy.position.distance_to(orbiters[i].position) < 1.0:
					_hit(enemy, damage * 0.4, false, false)
					break

func dash() -> void:
	if mode != "playing" or dash_clock > 0: return
	dash_direction = _movement()
	if dash_direction.length_squared() < 0.01: dash_direction = -player.basis.z.normalized()
	dash_time = 0.18
	dash_clock = 3.8 - rank_of("dash") * 0.6
	invulnerable = maxf(invulnerable, 0.3)
	vfx.burst(player.position + Vector3.UP * 0.3, Color("a0ffdf"), 12)
	haptic(12)

func special() -> void:
	if mode != "playing" or special_charge < 100: return
	special_charge = 0
	invulnerable = 1.0
	_cast_move(technique_id,2.2)
	haptic(40)

func technique() -> void:
	if mode != "playing" or technique_clock > 0: return
	technique_clock = RushRoster.move(technique_id).cooldown
	invulnerable = maxf(invulnerable,.35)
	_cast_move(technique_id,1.0)

func _cast_move(id: String, strength: float) -> void:
	var tint: Color = selected_character().color
	player.punch()
	shake = .18*minf(strength,1.5)
	match id:
		"barrage":
			barrage_time=1.0
			barrage_tick=0
			skill_multiplier=strength
			audio.play(load("res://assets/whoosh.wav"),1.3)
		"quake":
			player.slam_time=.55
			vfx.quake(player.position,tint,4.2+strength*.4)
			_area_hit(4.2+strength*.4,damage*2.6*strength)
			for enemy in enemies:
				if enemy.position.distance_to(player.position)<4.6: enemy.launch_time=.5; enemy.windup=0; enemy.warning.visible=false
			audio.play(load("res://assets/slam.wav"))
			hit_stop = .065
		"cyclone":
			cyclone_clock = 1.4
			cyclone_tick = 0
			skill_multiplier = strength
			player.spin_time = 1.4
			audio.play(load("res://assets/whoosh.wav"),.8)
		"thunder":
			var origin := player.position+Vector3.UP
			var count := 0
			var targets := enemies.duplicate()
			targets.sort_custom(func(a,b): return a.position.distance_squared_to(player.position)<b.position.distance_squared_to(player.position))
			for enemy: RushBoxer in targets:
				if count >= 8 or enemy.position.distance_to(player.position)>6: break
				vfx.beam(origin,enemy.position+Vector3.UP,Color("98d8ff"))
				origin = enemy.position+Vector3.UP
				_hit(enemy,damage*2.1*strength,false,true)
				count += 1
			audio.play(load("res://assets/electric.wav"))
		"dragon":
			player.launch_time=.65
			vfx.cyclone(player.position,Color("ffb27f"),2.5)
			for enemy: RushBoxer in enemies.duplicate():
				if enemy.position.distance_to(player.position)<3.0:
					enemy.launch_time=.65
					_hit(enemy,damage*4*strength,false,true)
			audio.play(load("res://assets/slam.wav"),1.3)
		"meteor":
			projectile_position=player.position+Vector3.UP*.65
			projectile_direction=-player.basis.z.normalized()
			projectile_time=1.1
			projectile_hits.clear()
			skill_multiplier=strength
			audio.play(load("res://assets/whoosh.wav"),.65)
	haptic(22)

func _update_technique(delta: float) -> void:
	if barrage_time > 0:
		barrage_time -= delta
		barrage_tick -= delta
		if barrage_tick <= 0:
			barrage_tick=.16
			player.punch()
			var closest: RushBoxer
			var distance := 3.2
			for enemy in enemies:
				if enemy.position.distance_to(player.position)<distance:
					distance=enemy.position.distance_to(player.position)
					closest=enemy
			if closest != null:
				player.face(closest.position-player.position)
				vfx.beam(player.position+Vector3.UP,closest.position+Vector3.UP,Color("b6ffee"))
				_hit(closest,damage*.95*skill_multiplier,false,true)
				audio.play(HIT_SOUND,1.3)
	if cyclone_clock > 0:
		cyclone_clock -= delta
		cyclone_tick -= delta
		invulnerable = maxf(invulnerable,.08)
		if cyclone_tick <= 0:
			cyclone_tick=.22
			vfx.cyclone(player.position,selected_character().color,2.7)
			_area_hit(2.9,damage*.52*skill_multiplier)
	if projectile_time > 0:
		projectile_time -= delta
		var previous := projectile_position
		projectile_position += projectile_direction*12*delta
		vfx.beam(projectile_position+Vector3.LEFT*.45,projectile_position+Vector3.RIGHT*.45,Color("ffb05e"))
		vfx.burst(projectile_position,Color("ffdd8c"),3,.4)
		for enemy: RushBoxer in enemies.duplicate():
			if enemy.get_instance_id() in projectile_hits: continue
			var point := Geometry3D.get_closest_point_to_segment(enemy.position+Vector3.UP*.65,previous,projectile_position)
			if point.distance_to(enemy.position+Vector3.UP*.65)<1.2:
				projectile_hits.append(enemy.get_instance_id())
				_hit(enemy,damage*3*skill_multiplier,false,true)

func _advance_waves(delta: float) -> bool:
	if not director.clearing and director.spawned >= director.quota and enemies.is_empty():
		director.clearing = true
		director.rest = 2.4
		completed_waves = wave
		hp = minf(max_hp,hp+max_hp*(.15 if director.boss_wave() else .07))
		special_charge = minf(100,special_charge+10)
		run_coins += 15 if director.boss_wave() else 5
		for pickup in pickups: pickup.visible=false; xp+=1
		pickups.clear()
		checkpoint()
		audio.play(LEVEL_SOUND,.85)
		if wave >= director.target:
			finish_run(true)
			return true
		hud.toast("WAVE %d CLEAR  /  RECOVERY +%d HP" % [wave,int(max_hp*(.15 if director.boss_wave() else .07))])
	if director.clearing:
		director.rest -= delta
		if xp >= xp_needed: _level_up(); return true
		if director.rest <= 0:
			director.advance()
			wave=director.number
			boss=null
			boss_spawned=false
			boss_defeated=false
			spawn_clock=.2
			if run_mode == "ladder":
				stage=mini(4,(wave-1)/5)
				arena.set_stage(stage)
				_reset_combat_camera()
				_play_music("street" if stage==1 else "fight")
			hud.toast("WAVE %d / %d  ·  %s" % [wave,director.target,director.modifier()])
	return false

func selected_character() -> Dictionary:
	var id: String = MobileCore.save.data.progress.get("selected_character","atlas")
	return RushRoster.character(id if RushRoster.owned(MobileCore.save,"character",id) else "atlas")

func selected_move() -> String:
	var id: String = MobileCore.save.data.progress.get("selected_move",selected_character().move)
	return id if RushRoster.owned(MobileCore.save,"move",id) else selected_character().move

func _play_music(track: String) -> void:
	var stream: AudioStream = load("res://assets/music_"+track+".ogg")
	stream.loop = true
	if music.stream == stream and music.playing: return
	music.stop()
	music.stream=stream
	music.play()

func _area_hit(radius: float, amount: float) -> void:
	for enemy: RushBoxer in enemies.duplicate():
		if enemy.active and enemy.position.distance_to(player.position) < radius: _hit(enemy, amount, false, false)

func _movement() -> Vector3:
	if hud == null: return Vector3.ZERO
	var input := hud.stick.vector
	input += Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	input = input.limit_length()
	return Vector3(input.x + input.y, 0, input.y - input.x) / sqrt(2.0)

func _spawn(at: Vector3, kind: String = "") -> RushBoxer:
	var enemy: RushBoxer
	for candidate in enemy_pool:
		if not candidate.active and not candidate.dying:
			enemy = candidate
			break
	if enemy==null and not knockouts.is_empty():
		enemy=knockouts.pop_front()
		enemy.finish_defeat()
	if enemy == null: return null
	if kind.is_empty():
		var roll := randf()
		kind = "brute" if wave >= 3 and roll < 0.18 else ("runner" if wave >= 2 and roll < 0.40 else "rookie")
	enemy.configure(kind)
	enemy.position = RushArenaLayout.constrain(at,stage,.4)
	var factor: float = RushBalance.STAGES[stage].difficulty
	enemy.max_health = (24 + wave * (3.0 if run_mode == "classic" else .85)) * factor * {"rookie": 1.0, "runner": 0.75, "brute": 2.4, "boss": 18.0}.get(kind, 1)
	if kind == "boss" and run_mode != "classic": enemy.max_health = (180+wave*12)*factor
	enemy.health = enemy.max_health
	enemy.speed = (1.3 + minf(1.0,wave * 0.04)) * {"rookie": 1.0, "runner": 1.6, "brute": 0.7, "boss": 0.8}.get(kind, 1)
	enemy.face(player.position - at)
	enemies.append(enemy)
	return enemy

func _spawn_boss() -> void:
	if enemies.size() >= RushBalance.MAX_ENEMIES:
		var removed: RushBoxer = enemies.pop_back()
		removed.active = false
		removed.visible = false
	boss = _spawn(RushArenaLayout.spawn_point(stage,-PI*.5), "boss")
	boss_spawned = true
	hud.toast(RushBalance.STAGES[stage].boss + " enters the ring!")

func _attack() -> void:
	var nearest: RushBoxer
	var distance := reach
	for enemy in enemies:
		var d := enemy.position.distance_to(player.position)
		if d < distance:
			distance = d
			nearest = enemy
	if nearest == null: return
	attack_clock = cooldown
	player.face(nearest.position - player.position)
	player.punch()
	audio.play(HIT_SOUND, randf_range(0.9, 1.15))
	var direction := (nearest.position - player.position).normalized()
	var origin := nearest.position
	var direct: Array[RushBoxer] = []
	for enemy: RushBoxer in enemies.duplicate():
		var offset := enemy.position - player.position
		if offset.length() <= reach and offset.normalized().dot(direction) > 0.25:
			direct.append(enemy)
			var critical := randf() < rank_of("crit") * 0.12
			_hit(enemy, damage * (2 if critical else 1), true, critical)
	var arcs := rank_of("chain")
	for enemy: RushBoxer in enemies.duplicate():
		if arcs <= 0: break
		if enemy not in direct and enemy.position.distance_to(origin) < 3.2:
			vfx.beam(origin + Vector3.UP, enemy.position + Vector3.UP, Color("a5caff"))
			_hit(enemy, damage * 0.55, false, false)
			arcs -= 1
	haptic(8)

func _hit(enemy: RushBoxer, amount: float, status: bool = true, critical: bool = false) -> void:
	if not enemy.active: return
	enemy.health -= amount
	enemy.hurt(vfx.enabled)
	if critical:hit_stop=maxf(hit_stop,.035)
	enemy.knockback = (enemy.position - player.position).normalized() * (2.0 if enemy.role == "boss" else 6.0)
	if status:
		if rank_of("burn") > 0:
			enemy.burn = 3
			enemy.burn_damage = rank_of("burn") * 4
		if rank_of("frost") > 0: enemy.frost = 1.0 + rank_of("frost") * 0.6
	vfx.burst(enemy.position + Vector3.UP, Color("acdcff") if enemy.frost > 0 else Color("ffca62"), 5)
	vfx.damage_number(enemy.position, ceili(amount), critical)
	if enemy.health <= 0:
		if enemy.role == "boss": audio.play(load("res://assets/ko.wav")); hit_stop=.08
		kills += 1
		combo += 1
		combo_clock = 4
		run_coins += 3 if enemy.role != "boss" else 30
		special_charge = minf(100, special_charge + 6 * (1 + rank_of("fury") * 0.25))
		hp = minf(max_hp, hp + rank_of("leech"))
		if enemy.role == "boss": boss_defeated = true
		if pickups.size() < 64:
			for pickup in pickup_pool:
				if not pickup.visible:
					pickup.position = enemy.position + Vector3.UP * 0.3
					pickup.visible = true
					pickups.append(pickup)
					break
		else: xp += 1
		enemies.erase(enemy)
		enemy.begin_defeat((enemy.position-player.position).normalized())
		knockouts.append(enemy)
		if knockouts.size()>10:knockouts.pop_front().finish_defeat()
		if impact_voice_clock<=0:
			audio.play(load("res://assets/fall.wav"),randf_range(.85,1.1))
			impact_voice_clock=.16

func rank_of(id: String) -> int:
	return int(ranks.get(id, 0))

func _level_up() -> void:
	if mode != "playing" or xp < xp_needed: return
	xp -= xp_needed
	level += 1
	xp_needed += 3
	options = RushBalance.choices(ranks, hp < max_hp)
	if options.is_empty(): return
	mode = "upgrade"
	audio.play(LEVEL_SOUND)
	hud.abilities(options)

func reroll() -> void:
	if mode != "upgrade" or rerolls <= 0: return
	rerolls -= 1
	options = RushBalance.choices(ranks, hp < max_hp)
	hud.abilities(options)

func choose_ability(id: String) -> void:
	if mode != "upgrade" or hud.upgrade_closing: return
	var offered := false
	for entry in options:
		if entry.id == id: offered = true
	if not offered: return
	ranks[id] = rank_of(id) + 1
	match id:
		"power": damage *= 1.25
		"speed": cooldown = maxf(0.18, cooldown * 0.85)
		"range": reach += 0.35
		"heal": hp = minf(max_hp, hp + 40)
		"nova": nova = true; nova_clock = 0
		"feet": move_speed *= 1.12
		"vitality": max_hp += 20; hp += 20
	hud.close_upgrade()

func haptic(duration: int) -> void:
	if MobileCore.save.data.settings.get("haptics", true) and (OS.has_feature("android") or OS.has_feature("ios")):
		Input.vibrate_handheld(duration)

func _frame_showroom() -> void:
	if mode!="home":
		if mode in ["playing","paused","upgrade","defeat"]:_reset_combat_camera()
		return
	if hud.current_page=="circuits":
		_frame_venue()
		return
	var viewport := get_viewport().get_visible_rect().size
	camera.size = 5.5 * maxf(1.0, (viewport.x/viewport.y) / (540.0/960.0))

func has_resume() -> bool:
	var pending: Dictionary = MobileCore.save.data.progress.get("pending_run",{})
	return RushRunSnapshot.valid(pending.get("state")) and not MobileCore.save.data.transactions.has(str(pending.get("id","")))

func resume_saved_run() -> void:
	if mode != "home" or not has_resume(): return
	var pending: Dictionary = MobileCore.save.data.progress.pending_run.duplicate(true)
	restoring=true
	run_mode=pending.state.run_mode
	stage=pending.state.stage
	# A ladder save may legitimately be beyond the separately unlocked circuit.
	var stored_stage := stage
	stage=0
	start_run()
	restoring=false
	if mode != "playing": return
	stage=stored_stage
	run_id=pending.id
	RushRunSnapshot.restore(self,pending.state)
	hud.toast("Fight restored. Resume when you are ready.")

func bank_saved_run() -> void:
	if mode != "home": return
	var amount := RushProgress.recover(MobileCore.save)
	if amount < 0: hud.toast("Unable to bank the saved fight. Free storage and retry."); return
	go_home()
	hud.toast("Saved fight banked: %d coins."%amount)

func _exit_tree() -> void:
	if music != null:
		music.stop()
		music.stream=null

func preview_character(id:String) -> void:
	if mode!="home":return
	_clear_combat()
	player.set_character(id)
	player.scale*=1.78
	player.position=Vector3.ZERO
	player.face(Vector3(.6,0,1))
	_frame_showroom()

func demo_move(id:String) -> void:
	if mode!="home":return
	hud.move_demo(id)
	_clear_combat()
	for i in 4:
		var enemy:=_spawn(Vector3(-1.8+i*1.2,0,-1.7),"rookie")
		enemy.health=100000
	player.face(Vector3.FORWARD)
	_cast_move(id,1.0)

func ads_removed() -> bool:
	return MobileCore.save.data.entitlements.get("remove_ads",false)

func _knockout() -> void:
	if mode!="playing":return
	if revive_used:
		finish_run(false)
		return
	mode="defeat"
	hp=0
	checkpoint()
	hud.revive_offer()

func request_revive() -> void:
	if mode!="defeat" or revive_used:return
	if not checkpoint():return
	MobileCore.commerce.reward_context("revive",{"run_id":run_id})

func request_victory_bonus() -> void:
	if mode!="result" or not result_won or result_bonus_claimed():return
	if not MobileCore.save.data.transactions.has(run_id):return
	MobileCore.commerce.reward_context("victory_bonus",{"run_id":run_id})

func result_bonus_claimed() -> bool:
	var record:Dictionary=MobileCore.save.data.progress.get("last_result",{})
	return record.get("id")==run_id and record.get("bonus_claimed",false)

func _claim_ad_reward(id:String) -> void:
	var outcome:=RushAdRewards.claim(MobileCore.save,id)
	if not outcome.get("ok",false):
		if outcome.get("retry",false):hud.toast("Reward is saved for retry. Free some storage, then reopen the game.")
		return
	if outcome.benefit=="revive" and outcome.run_id==run_id and mode=="defeat":
		hp=outcome.hp
		revive_used=true
		invulnerable=3
		for enemy in enemies:
			var away:=enemy.position-player.position
			if away.length()<2.3:
				if away.length()<.01:away=Vector3.RIGHT
				enemy.position=RushArenaLayout.constrain(player.position+away.normalized()*3,stage,.5)
				enemy.windup=0
				enemy.warning.visible=false
		mode="paused"
		checkpoint()
		hud.paused()
		hud.toast("Back on your feet. 60% health + 3 seconds of protection.")
	elif outcome.benefit=="victory_bonus":
		if mode=="result" and outcome.run_id==run_id:hud.result(result_won,true)
		hud.toast("Extra %d coins saved."%outcome.coins)

func leave_result() -> void:
	_transition_result(false)

func replay_result() -> void:
	_transition_result(true)

func _transition_result(replay:bool) -> void:
	if mode!="result" or not MobileCore.save.data.transactions.has(run_id):return
	var key:=run_id
	go_home()
	var progress:Dictionary=MobileCore.save.data.progress
	if not ads_removed() and int(progress.get("runs",0))%3==0 and progress.get("last_interstitial_run","")!=key and progress.get("last_rewarded_run","")!=key:
		var next:=MobileCore.save.data.duplicate(true)
		next.progress.last_interstitial_run=key
		if MobileCore.save.commit(next):
			queued_replay=replay
			MobileCore.commerce.interstitial("post_run")
			return
	if replay:start_run()

func _commerce_transition(_success:bool,_message:String) -> void:
	if queued_replay and mode=="home" and MobileCore.commerce.pending.is_empty():
		queued_replay=false
		start_run()

func _reset_combat_camera() -> void:
	follow_camera.update(camera,player.position,get_viewport().get_visible_rect().size,0,true)

func _update_knockouts(delta:float) -> void:
	for enemy in knockouts.duplicate():
		if enemy.animate_defeat(delta,stage):knockouts.erase(enemy)

func preview_venue(index:int) -> void:
	if mode!="home":return
	_clear_combat()
	player.visible=false
	podium.visible=false
	arena.showcase.visible=false
	arena.showroom(false)
	arena.set_stage(index)
	_frame_venue()

func _frame_venue() -> void:
	var viewport:=get_viewport().get_visible_rect().size
	camera.size=25.5*maxf(1,(viewport.x/viewport.y)/(540.0/960.0))
	camera.position=camera_home
	camera.look_at(Vector3.ZERO)
	# Lift the actual arena into the upper preview, above the venue selector.
	camera.position-=camera.basis.y*(camera.size/(viewport.x/viewport.y))*.21
