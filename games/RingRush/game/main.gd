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
var ranged_combat:=RushRangedCombat.new()
var arsenal:=RushRunArsenal.new()
var ultimate:=RushUltimates.new()
var support:=RushSupportCombat.new()
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
var growth:Dictionary={}
var records:Dictionary={}
var challenge_contract:=false
var shutdown_started:=false
var cast_radius:=1.0
var cast_tint:=Color.WHITE
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
var music: CoreMusicPlayer
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
var preview_saved_stage:=-1

func _ready() -> void:
	get_tree().auto_accept_quit=false
	var backend = JSON.parse_string(FileAccess.get_file_as_string("res://config/backend.json"))
	var url: String = backend.get("api_url", "")
	if OS.is_debug_build() or OS.has_feature("playtest"):
		url = OS.get_environment("RINGRUSH_API_URL") if OS.has_environment("RINGRUSH_API_URL") else backend.get("development_api_url", url)
	MobileCore.account.configure(MobileCore.save, backend.get("game_id", "ringrush"), url, func(): return mode == "home" and hud != null and hud.current_page in ["home", "account"] and MobileCore.commerce.pending.is_empty())
	var profile_ready:=RushBootstrap.prepare(MobileCore.save)
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
	music = CoreMusicPlayer.new()
	music.configure(RushMusic.CUES)
	add_child(music)
	music.volume_db = -15
	player = RushBoxer.new()
	add_child(player)
	player.build(true)
	add_child(support)
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
	MobileCore.account.profile_loaded.connect(_account_profile_loaded)
	apply_settings()
	MobileCore.commerce.reward_ready.connect(_claim_ad_reward)
	MobileCore.commerce.completed.connect(_commerce_transition)
	for receipt_id in MobileCore.save.data.get("reward_receipts",{}).keys(): _claim_ad_reward(receipt_id)
	var recovered := 0 if has_resume() else RushProgress.recover(MobileCore.save)
	go_home()
	if not profile_ready:hud.toast("Could not update your profile. Free storage and restart.")
	elif MobileCore.save.unsupported_version: hud.toast("This save needs a newer game version. Progress is read-only.")
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
	vfx.detail=0 if low or MobileCore.save.data.settings.get("reduced_motion",false) else 1
	arena.set_quality(low)
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if low else Viewport.MSAA_2X
	if not vfx.enabled: vfx.clear()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if mode in ["playing","paused","upgrade","defeat"]:
			checkpoint()
			if mode == "playing": pause_run()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:request_quit()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE:
		if mode == "playing": pause_run()
		elif mode == "paused": resume_run()
		elif mode=="home" and hud.current_page=="move_demo":hud.moves(true)
	elif event.keycode == KEY_SPACE: dash()
	elif event.keycode == KEY_E: special()
	elif event.keycode == KEY_Q: technique()

func _clear_combat() -> void:
	ranged_combat.clear()
	arsenal.clear();ultimate.clear();support.clear()
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
	_end_demo()
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
	arena.showcase.select_fighter(selected_character().id)
	# Lights and environment still affect the showroom while arena geometry is hidden.
	camera.position = Vector3(5, 3.7, 8)
	camera.look_at(Vector3(0, 1.75, 0))
	camera.position -= camera.basis.y * 1.30
	hud.current_page="home"
	_frame_showroom()
	_play_music("menu")
	hud.home()

func select_stage(index: int) -> void:
	if mode != "home" or not RushChallenges.available(MobileCore.save,run_mode,index): return
	stage = index
	hud.home()

func start_run() -> void:
	if MobileCore.account.busy:
		hud.toast("Finishing cloud sync. Please try again in a moment.")
		return
	if has_resume() and not restoring:
		hud.toast("Resume your saved fight, or bank it from the challenge menu.")
		return
	if MobileCore.save.unsupported_version:
		hud.toast("Update the game to use this newer save. Your file has been preserved.")
		return
	if mode not in ["home", "result"] or not MobileCore.commerce.pending.is_empty(): return
	if run_mode == "ladder": stage = 0
	if run_mode == "rift":stage=RushChallenges.SECRET_STAGE
	if not RushChallenges.available(MobileCore.save,run_mode,stage):return
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
	growth=RushGrowth.snapshot(MobileCore.save,fighter,technique_id,challenge_contract)
	records.clear()
	var badge_bonus:=RushAchievements.bonuses(MobileCore.save.data)
	max_hp = RushTraining.value(fighter,"health",RushTraining.level(MobileCore.save,"health"))+badge_bonus.health
	hp = max_hp
	damage = RushTraining.value(fighter,"power",RushTraining.level(MobileCore.save,"power"))+badge_bonus.power
	reach = 2.0
	move_speed = RushTraining.value(fighter,"footwork",RushTraining.level(MobileCore.save,"footwork"))
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
	ranks[fighter.rank] = fighter.get("ranks",2 if fighter.id == "titan" else 1)
	if fighter.rank == "feet": move_speed *= 1.06
	if fighter.rank == "speed": cooldown *= .90
	rerolls = 2
	technique_clock = 0
	completed_waves = 0
	revive_used=false
	director.begin(run_mode)
	dash_clock = 0
	dash_time = 0
	invulnerable = 0
	special_charge = RushTraining.value(fighter,"charge",RushTraining.level(MobileCore.save,"charge"))
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
	_play_music(run_mode)
	if not restoring:
		support.begin(MobileCore.save)
		checkpoint()
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
		run_coins=ceili(run_coins*float(growth.get("coins",1)))
	mode = "result"
	var saved := RushProgress.settle(MobileCore.save, run_id, run_coins, stage, kills, result_won, run_mode, completed_waves,records)
	hud.result(result_won, saved)

func _process(delta: float) -> void:
	if mode in ["playing","home"]:player.animate(delta, mode == "playing" and _movement().length_squared() > 0.01)
	if mode == "home":
		if hud.current_page=="move_demo":
			_update_technique(delta)
			for enemy in enemies:enemy.animate(delta,false)
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
	hp = minf(max_hp, hp + rank_of("regen") * .25 * delta)
	special_charge = minf(100, special_charge + delta * 0.25 * (1 + rank_of("fury") * 0.15))
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
	player.position = RushArenaLayout.move(player.position,movement*(16 if dash_time>0 else move_speed*(1.08 if support.speed_time>0 else 1))*delta,stage)
	if movement.length_squared() > 0.01: player.face(movement)
	spawn_clock -= delta
	if spawn_clock <= 0:
		if run_mode == "classic" and elapsed < 90:
			spawn_clock = maxf(.40,1.1-wave*.11) / float(RushBalance.STAGES[stage].difficulty)
			if enemies.size() < RushBalance.MAX_ENEMIES-(0 if boss_spawned else 1):
				var angle := randf()*TAU
				_spawn(RushArenaLayout.spawn_point(stage,angle))
		elif run_mode != "classic" and not director.clearing and director.spawned < director.quota:
			spawn_clock = director.spawn_delay()
			if director.boss_wave() and director.spawned == 0: _spawn_boss()
			else:
				var angle := randf()*TAU
				var kind := RushEncounterRoster.pick(stage,wave,director.spawned)
				_spawn(RushArenaLayout.spawn_point(stage,angle),kind)
			director.spawned += 1
	if arena.update_hazards(elapsed):
		for vent in arena.vents:
			if player.position.distance_to(vent.global_position) < 1.18*RushArenaLayout.SCALE: _take_damage(12)
		if int(elapsed*8)%3 == 0:
			for vent in arena.vents: vfx.burst(vent.global_position,Color("ffc58e"),2,.7)
	attack_clock -= delta
	if attack_clock <= 0: _attack()
	_build_neighbors()
	for enemy: RushBoxer in enemies.duplicate():
		if enemy.active: _update_enemy(enemy, delta)
	if hp <= 0:
		_knockout()
		return
	_update_skills(delta)
	arsenal.update(self,delta)
	ultimate.update(self,delta)
	support.update(self,delta)
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
	if enemy.role=="boss":
		enemy.encounter.update(self,enemy,delta)
		return
	if enemy.launch_time > 0:
		enemy.rush_time=0
		enemy.windup=0
		enemy.warning.visible=false
		enemy.position += enemy.knockback*delta
		enemy.knockback=enemy.knockback.move_toward(Vector3.ZERO,delta*20)
		enemy.position=RushArenaLayout.move(start_position,enemy.position-start_position,stage,.33*enemy.scale.x)
		enemy.animate(delta,false)
		return
	var direction := player.position - enemy.position
	var distance := direction.length()
	var slow := 0.65 if enemy.frost > 0 else 1.0
	if enemy.rush_time>0:
		enemy.rush_time=maxf(0,enemy.rush_time-delta*slow)
		enemy.position=RushArenaLayout.move(enemy.position,enemy.rush_direction*9*delta*slow,stage,.4)
		var point:=Geometry3D.get_closest_point_to_segment(player.position,start_position,enemy.position)
		if point.distance_to(player.position)<.85 and not enemy.rush_hit:
			enemy.rush_hit=true
			_take_damage(14)
		vfx.stroke(start_position+Vector3.UP*.15,enemy.position+Vector3.UP*.15,Color("ff885f"),.14,.18)
		enemy.animate(delta,true)
		return
	if enemy.windup<=0:enemy.face(direction)
	var ranged:bool=enemy.role in ["spark","hexer","drone","spitter","wisp","stinger","sentry"]
	var charging:bool=enemy.role in ["charger","revenant","hound"]
	var radius:float=2.5 if enemy.role in ["brute","guard"] else 1.05
	if enemy.windup > 0:
		enemy.windup -= delta * slow
		enemy.warning.visible = true
		var size := radius / enemy.scale.x
		enemy.warning.scale = Vector3(size, 0.08, size)
		if ranged:
			enemy.warning.global_position=enemy.attack_target+Vector3.UP*.14
			enemy.warning.scale=Vector3.ONE*1.25/enemy.scale.x
			enemy.warning.scale.y=.08
		elif charging:
			vfx.stroke(enemy.position+Vector3.UP*.12,enemy.attack_target+Vector3.UP*.12,Color("ff876b"),.09,.06)
		if enemy.windup <= 0:
			enemy.warning.visible = false
			enemy.warning.position=Vector3.UP*.12
			enemy.punch()
			enemy.attack_timer = {"stinger":2.0,"sentry":3.2}.get(enemy.role,2.6 if ranged or charging else 1.5)
			if ranged:
				var aim:Vector3=(enemy.attack_target-enemy.position).normalized()
				var kind:String={"spitter":"acid","wisp":"seeker"}.get(enemy.role,"enemy")
				var source:Vector3=enemy.position+Vector3.UP*.8+aim*.5
				var spread:Array=[-.22,0,.22] if enemy.role=="drone" else ([-.12,.12] if enemy.role=="sentry" else [0])
				for angle in spread:ranged_combat.fire(source,aim.rotated(Vector3.UP,angle),8 if enemy.role=="drone" else 10,kind,true,1.4 if enemy.role=="spitter" else 0,false,player if enemy.role=="wisp" else null)
				vfx.muzzle(source,Color("ff9981"),.65)
			elif charging:
				enemy.rush_direction=(enemy.attack_target-enemy.position).normalized()
				enemy.rush_time=.5
				enemy.rush_hit=false
			else:
				if distance < radius:_take_damage(10 if enemy.role in ["brute","guard"] else 6)
				if radius>2:vfx.ring(enemy.position,Color("ff7965"),radius,.45,true)
	else:
		enemy.attack_timer -= delta * slow
		var separation := Vector3.ZERO
		var cell := Vector2i(floori(enemy.position.x / 1.2), floori(enemy.position.z / 1.2))
		for x in range(-1, 2):
			for y in range(-1, 2):
				for other: RushBoxer in neighbor_grid.get(cell + Vector2i(x, y), []):
					var away := enemy.position - other.position
					if away.length_squared() < 0.81 and away.length_squared() > 0.001: separation += away.normalized() * 0.8
		var preferred:float=3.8 if ranged else .9
		if distance>preferred:enemy.position+=(RushArenaLayout.steer(enemy.position,player.position,stage)*enemy.speed*slow+separation)*delta
		elif ranged and distance<2.4:enemy.position+=(-direction.normalized()*enemy.speed*slow+separation)*delta
		var trigger:float=6.0 if ranged else (4.5 if charging else radius+.05)
		if distance<trigger and enemy.attack_timer<=0 and (not ranged or RushRangedCombat._wall_fraction(enemy.position,player.position,stage,0)>=1):
			enemy.windup=1.1 if ranged else (.85 if charging or radius>2 else .36)
			enemy.attack_target=player.position
	enemy.position += enemy.knockback * delta
	enemy.knockback = enemy.knockback.move_toward(Vector3.ZERO, delta * 20)
	enemy.position=RushArenaLayout.move(start_position,enemy.position-start_position,stage,.33*enemy.scale.x)
	enemy.animate(delta, distance > 0.9 and enemy.windup <= 0)

func _take_damage(amount: float) -> void:
	if invulnerable > 0 or hp <= 0: return
	hp = maxf(0, hp - amount * (.8 if support.shield_time>0 else 1) * float(growth.get("enemy_damage",1)) * (1 - rank_of("armor") * 0.08)*(1-float(growth.get("grit",0))))
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
		vfx.ring(player.position, Color("49e0bf"), 3.8,.45,true)
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
	record_action("dodges")
	support.on_dodge(self)
	dash_direction = _movement()
	if dash_direction.length_squared() < 0.01: dash_direction = -player.basis.z.normalized()
	dash_time = 0.18
	dash_clock = 3.8 - rank_of("dash") * 0.6
	invulnerable = maxf(invulnerable, 0.3)
	for enemy in enemies:
		if enemy.role=="boss" and enemy.encounter.on_dodge(self,enemy):invulnerable=maxf(invulnerable,.36)
	vfx.burst(player.position + Vector3.UP * 0.3, Color("a0ffdf"), 12)
	haptic(12)

func special() -> void:
	if mode != "playing" or special_charge < 100: return
	special_charge = 0
	record_action("ultimates")
	invulnerable = 1.0
	ultimate.activate(self)
	haptic(40)

func technique() -> void:
	if mode != "playing" or technique_clock > 0: return
	technique_clock = technique_cooldown()
	invulnerable = maxf(invulnerable,.35)
	_cast_move(technique_id,1.0)
	support.on_skill(self)

func _cast_move(id: String, strength: float) -> void:
	for enemy in enemies:
		if enemy.role=="boss":enemy.encounter.arm_break()
	var skill_rank:int=int(growth.get("skill_level",1))
	var upgrades:=RushSkillGrowth.stats(skill_rank)
	var fighter:=RushRoster.character(player.character_id)
	var charged:float=strength
	strength*=upgrades.damage*(1+float(fighter.get("skill_bonus",0)))
	cast_radius=upgrades.radius*(1+float(fighter.get("range_bonus",0)))
	var tint: Color = RushSkillGrowth.tint(id,skill_rank)
	cast_tint=tint
	record_action("casts_"+id)
	if upgrades.stage>0:
		var second:=RushSkillGrowth.tint(id,skill_rank,true)
		vfx.ring(player.position,second,2.1*cast_radius,.5,true)
		if upgrades.stage>1:
			vfx.ring(player.position,tint,3.2*cast_radius,.65,true)
			vfx.stroke(player.position,player.position+Vector3.UP*2.8,second,.14,.4)
	player.punch()
	vfx.ring(player.position,tint,1.1,.3,true)
	shake = .18*minf(strength,1.5)
	match id:
		"barrage":
			barrage_time=1.0
			barrage_tick=0
			skill_multiplier=strength
			audio.play(load("res://assets/whoosh.wav"),1.3)
		"quake":
			player.slam_time=.55;player.punch()
			vfx.quake(player.position,tint,(4.2+charged*.4)*cast_radius)
			_area_hit((4.2+charged*.4)*cast_radius,damage*2.6*strength,true)
			for enemy in enemies:
				if enemy.role!="boss" and enemy.position.distance_to(player.position)<4.6*cast_radius: enemy.launch_time=.5; enemy.windup=0; enemy.warning.visible=false
			audio.play(load("res://assets/slam.wav"))
			hit_stop = .065
		"cyclone":
			cyclone_clock = 1.4
			cyclone_tick = 0
			skill_multiplier = strength
			player.spin_time = 1.4
			audio.play(load("res://assets/whoosh.wav"),.8)
		"thunder":
			vfx.lightning(player.position+Vector3.UP*5,player.position+Vector3.UP*.2,tint)
			var origin := player.position+Vector3.UP
			var count := 0
			var targets := enemies.duplicate()
			targets.sort_custom(func(a,b): return a.position.distance_squared_to(player.position)<b.position.distance_squared_to(player.position))
			for enemy: RushBoxer in targets:
				if count >= 8+upgrades.stage*2 or enemy.position.distance_to(player.position)>6*cast_radius: break
				vfx.lightning(origin,enemy.position+Vector3.UP,tint)
				origin = enemy.position+Vector3.UP
				_hit(enemy,damage*2.1*strength,false,true,true)
				count += 1
			audio.play(load("res://assets/electric.wav"))
		"dragon":
			player.launch_time=.65
			vfx.cyclone(player.position,tint,2.5*cast_radius)
			vfx.stroke(player.position+Vector3.UP*.3,player.position+Vector3.UP*3.5,tint,.26,.5)
			for enemy: RushBoxer in enemies.duplicate():
				if enemy.position.distance_to(player.position)<3.0*cast_radius:
					if enemy.role!="boss":enemy.launch_time=.65
					_hit(enemy,damage*4*strength,false,true,true)
			audio.play(load("res://assets/slam.wav"),1.3)
		"pulse","orb":
			ranged_combat.cast(self,id,strength,cast_radius,tint)
		"meteor":
			projectile_position=player.position+Vector3.UP*.65
			projectile_direction=-player.basis.z.normalized()
			projectile_time=1.1
			projectile_hits.clear()
			skill_multiplier=strength
			audio.play(load("res://assets/whoosh.wav"),.65)
	haptic(22)

func _update_technique(delta: float) -> void:
	ranged_combat.update(self,delta)
	if barrage_time > 0:
		barrage_time -= delta
		barrage_tick -= delta
		if barrage_tick <= 0:
			barrage_tick=.16
			player.punch()
			var closest: RushBoxer
			var distance := 3.2*cast_radius
			for enemy in enemies:
				if enemy.position.distance_to(player.position)<distance:
					distance=enemy.position.distance_to(player.position)
					closest=enemy
			vfx.strike(player.position,-player.basis.z,cast_tint)
			if closest != null:
				player.face(closest.position-player.position)
				vfx.beam(player.position+Vector3.UP,closest.position+Vector3.UP,Color("b6ffee"))
				_hit(closest,damage*.95*skill_multiplier,false,true,true)
				audio.play(HIT_SOUND,1.3)
	if cyclone_clock > 0:
		cyclone_clock -= delta
		cyclone_tick -= delta
		invulnerable = maxf(invulnerable,.08)
		if cyclone_tick <= 0:
			cyclone_tick=.22
			vfx.cyclone(player.position,cast_tint,2.7*cast_radius)
			_area_hit(2.9*cast_radius,damage*.52*skill_multiplier,true)
	if projectile_time > 0:
		projectile_time -= delta
		var previous := projectile_position
		projectile_position += projectile_direction*12*delta
		var edge:=RushArenaLayout.constrain(projectile_position,stage,0)
		if edge.distance_to(projectile_position)>.15:
			projectile_position=edge
			projectile_time=0
			vfx.wall_impact(edge,Color("ffc66b"))
		vfx.stroke(previous-projectile_direction*.6,projectile_position,cast_tint,.48*cast_radius,.14)
		vfx.stroke(previous,projectile_position+projectile_direction*.15,Color("fff1aa"),.20,.12)
		vfx.projectile(projectile_position,projectile_direction,cast_tint,"orb",.6*cast_radius)
		for enemy: RushBoxer in enemies.duplicate():
			if enemy.get_instance_id() in projectile_hits: continue
			var point := Geometry3D.get_closest_point_to_segment(enemy.position+Vector3.UP*.65,previous,projectile_position)
			if point.distance_to(enemy.position+Vector3.UP*.65)<1.2*cast_radius:
				projectile_hits.append(enemy.get_instance_id())
				_hit(enemy,damage*3*skill_multiplier,false,true,true)

func _advance_waves(delta: float) -> bool:
	if not director.clearing and director.spawned >= director.quota and enemies.is_empty():
		director.clearing = true
		ranged_combat.clear(true)
		director.rest = director.rest_duration()
		completed_waves = wave
		hp = minf(max_hp,hp+max_hp*(director.recovery()+float(growth.get("recovery",0))))
		special_charge = minf(100,special_charge+5)
		run_coins += 15 if director.boss_wave() else 5
		for pickup in pickups: pickup.visible=false; xp+=1
		pickups.clear()
		checkpoint()
		audio.play(LEVEL_SOUND,.85)
		if wave >= director.target:
			finish_run(true)
			return true
		hud.toast("WAVE %d CLEAR  /  RECOVERY +%d HP" % [wave,int(max_hp*(director.recovery()+float(growth.get("recovery",0))))])
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
				stage=RushChallenges.ladder_stage(wave)
				player.position=RushArenaLayout.constrain(player.position,stage)
				arena.set_stage(stage)
				_reset_combat_camera()
				_play_music(run_mode)
			hud.toast("WAVE %d / %d  ·  %s" % [wave,director.target,director.modifier()])
	return false

func selected_character() -> Dictionary:
	var id: String = MobileCore.save.data.progress.get("selected_character","atlas")
	return RushRoster.character(id if RushRoster.owned(MobileCore.save,"character",id) else "atlas")

func selected_move() -> String:
	var id: String = MobileCore.save.data.progress.get("selected_move",selected_character().move)
	return id if RushRoster.owned(MobileCore.save,"move",id) else selected_character().move

func _play_music(track:String) -> void:
	music.play_cue(track)

func _area_hit(radius: float, amount: float, technique_hit:bool=false) -> void:
	for enemy: RushBoxer in enemies.duplicate():
		if enemy.active and enemy.position.distance_to(player.position) < radius: _hit(enemy, amount, false, false, technique_hit)

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
	if kind.is_empty():kind=RushEncounterRoster.pick(stage,wave,randi_range(0,1000))
	if run_mode!="rift" or hud.current_page=="move_demo":kind={"bone":"runner","revenant":"charger","hexer":"spark"}.get(kind,kind)
	elif kind not in ["bone","revenant","hexer","boss"]:kind="bone"
	enemy.configure(kind,run_mode=="rift",RushEncounterRoster.boss_model(stage) if kind=="boss" else "")
	enemy.position = RushArenaLayout.constrain(at,stage,.4)
	var factor: float = RushBalance.STAGES[stage].difficulty*(1.15 if run_mode=="hell" else (.85 if run_mode=="blitz" else 1.0))
	enemy.max_health = (24 + wave * (3.0 if run_mode == "classic" else .85)) * factor * {"rookie": 1.0, "runner": 0.75, "brute": 2.4, "boss": 18.0,"charger":1.4,"spark":.9,"guard":1.8,"bone":.8,"revenant":1.3,"hexer":.95,"drone":.7,"spitter":1.5,"hound":.85,"wisp":.8,"stinger":.65,"sentry":1.8}.get(kind, 1)
	if kind == "boss" and run_mode != "classic": enemy.max_health = (180+wave*12)*factor
	enemy.max_health*=float(growth.get("enemy_hp",1)) if mode!="home" else 1.0
	if run_mode!="classic" and mode!="home" and kind!="boss":enemy.max_health*=1+maxi(0,wave-8)*.028
	enemy.health = enemy.max_health
	enemy.speed = (1.3 + minf(1.0,wave * 0.04)) * {"rookie": 1.0, "runner": 1.6, "brute": 0.7, "boss": 0.8,"charger":1.1,"spark":1.2,"guard":.85,"bone":1.3,"revenant":1.4,"hexer":1.1,"drone":1.3,"spitter":.75,"hound":1.6,"wisp":.95,"stinger":1.5,"sentry":.7}.get(kind, 1)
	enemy.speed*=float(growth.get("enemy_speed",1)) if mode!="home" else 1.0
	if run_mode=="hell":enemy.speed*=1.12
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
	hud.toast(RushBalance.STAGES[stage].boss + " approaches!")

func _attack() -> void:
	if player.is_mech() and ranged_combat.auto_fire(self):return
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
			var critical := randf() < rank_of("crit") * 0.08
			_hit(enemy, damage * (2 if critical else 1)*ultimate.damage_scale(), true, critical)
	var arcs := rank_of("chain")
	for enemy: RushBoxer in enemies.duplicate():
		if arcs <= 0: break
		if enemy not in direct and enemy.position.distance_to(origin) < 3.2:
			vfx.beam(origin + Vector3.UP, enemy.position + Vector3.UP, Color("a5caff"))
			_hit(enemy, damage * 0.55, false, false)
			arcs -= 1
	haptic(8)

func _hit(enemy: RushBoxer, amount: float, status: bool = true, critical: bool = false, technique_hit:bool=false, origin_kind:String="") -> void:
	if enemy.role=="guard" and status and enemy.windup<=0:
		amount*=.6
		vfx.ring(enemy.position,Color("6af3df"),.8,.22,true)
	if not enemy.active: return
	if enemy.role=="boss":
		amount*=enemy.encounter.damage_multiplier(self,enemy,status,technique_hit)
	if (status or technique_hit) and origin_kind not in ["support","passive","ultimate"]:
		support.on_hit();arsenal.on_hit(self,enemy)
	enemy.health -= amount
	enemy.hurt(vfx.enabled)
	if status or technique_hit:vfx.hit_flash(enemy.position+Vector3.UP,Color("fff1b4"))
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
		if origin_kind in ["ranged","passive"]:record_action("ranged_kos")
		kills += 1
		combo += 1
		records.best_combo=maxi(int(records.get("best_combo",0)),combo)
		if enemy.role=="boss":record_action("boss_kos")
		combo_clock = 4
		run_coins += 3 if enemy.role != "boss" else 30
		special_charge = minf(100, special_charge + 3.5 * (1 + rank_of("fury") * 0.15))
		hp = minf(max_hp, hp + rank_of("leech") * .35)
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
	options = RushBalance.choices(ranks, hp < max_hp,player.is_mech() or technique_id in ["pulse","orb","meteor"])
	if options.is_empty(): return
	mode = "upgrade"
	audio.play(LEVEL_SOUND)
	hud.abilities(options)

func reroll() -> void:
	if mode != "upgrade" or rerolls <= 0: return
	rerolls -= 1
	options = RushBalance.choices(ranks, hp < max_hp,player.is_mech() or technique_id in ["pulse","orb","meteor"])
	hud.abilities(options)

func choose_ability(id: String) -> void:
	if mode != "upgrade" or hud.upgrade_closing: return
	var offered := false
	for entry in options:
		if entry.id == id: offered = true
	if not offered: return
	ranks[id] = rank_of(id) + 1
	match id:
		"power": damage *= 1.18
		"speed": cooldown = maxf(0.18, cooldown * 0.90)
		"range": reach += 0.35
		"heal": hp = minf(max_hp, hp + 40)
		"nova": nova = true; nova_clock = 0
		"feet": move_speed *= 1.06
		"vitality": max_hp += 20; hp += 20
	hud.close_upgrade()

func haptic(duration: int) -> void:
	if MobileCore.save.data.settings.get("haptics", true) and (OS.has_feature("android") or OS.has_feature("ios")):
		Input.vibrate_handheld(duration)

func _frame_showroom() -> void:
	if mode!="home":
		if mode in ["playing","paused","upgrade","defeat"]:_reset_combat_camera()
		return
	if hud.current_page=="move_demo":
		_frame_demo()
		return
	if hud.current_page=="circuits":
		_frame_venue()
		return
	camera.position = Vector3(5,3.7,8)
	camera.look_at(Vector3(0,1.75,0))
	camera.position -= camera.basis.y*1.30
	# Pull the orthographic near plane behind the entire showroom, including the floor.
	camera.position += camera.basis.z*24
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
	_end_demo()
	if mode!="home":return
	_clear_combat()
	arena.showroom(true)
	arena.showcase.select_fighter(id)
	player.set_character(id)
	player.scale*=1.78
	player.position=Vector3.ZERO
	player.face(Vector3(.6,0,1))
	_frame_showroom()

func demo_move(id:String) -> void:
	if mode!="home":return
	if preview_saved_stage<0:preview_saved_stage=stage
	stage=0
	_clear_combat()
	player.set_character(selected_character().id)
	player.position=Vector3(0,0,-.8)
	player.face(Vector3.BACK)
	arena.showroom(false);arena.set_stage(0)
	hud.move_demo(id)
	_frame_demo()
	damage=RushTraining.value(selected_character(),"power",RushTraining.level(MobileCore.save,"power"))
	growth=RushGrowth.snapshot(MobileCore.save,selected_character(),id,false)
	for i in 4:
		var enemy:=_spawn(Vector3(-2.1+i*1.4,0,1.1),"rookie")
		enemy.health=100000
		if enemy.role=="boss":enemy.role="rookie"
	_cast_move(id,1.0)

func _end_demo() -> void:
	if preview_saved_stage>=0:stage=preview_saved_stage;preview_saved_stage=-1

func _frame_demo() -> void:
	var viewport:=get_viewport().get_visible_rect().size
	camera.size=7.5*maxf(1,(viewport.x/viewport.y)/(540.0/960.0))
	camera.position=Vector3(0,5.8,13)
	camera.look_at(Vector3(0,.6,0))
	camera.position-=camera.basis.y*1.5

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
	camera.size=25.5*RushArenaLayout.SCALE*maxf(1,(viewport.x/viewport.y)/(540.0/960.0))
	camera.position=camera_home
	camera.look_at(Vector3.ZERO)
	# Lift the actual arena into the upper preview, above the venue selector.
	camera.position-=camera.basis.y*(camera.size/(viewport.x/viewport.y))*.21

func record_action(id:String) -> void:
	if mode=="playing":records[id]=int(records.get(id,0))+1

func technique_cooldown() -> float:
	var fallback:float=RushTraining.value(RushRoster.character(player.character_id),"mastery",RushTraining.level(MobileCore.save,"mastery"))/100
	return RushRoster.move(technique_id).cooldown*float(growth.get("cooldown",fallback))*RushSkillGrowth.stats(int(growth.get("skill_level",1))).cooldown*(1-float(RushRoster.character(player.character_id).get("cooldown_bonus",0)))

func request_quit() -> void:
	if shutdown_started:return
	if mode in ["playing","paused","upgrade","defeat"] and not checkpoint():return
	shutdown_started=true
	set_process(false);set_physics_process(false)
	if music!=null:music.stop();music.stream=null
	if audio!=null:
		for voice in audio.voices:voice.stop();voice.stream=null
	# Let the audio driver release its playback references before SceneTree teardown.
	await get_tree().create_timer(.25).timeout
	get_tree().quit()

func _account_profile_loaded() -> void:
	if mode != "home": return
	var account_open := hud.current_page == "account"
	RushBootstrap.prepare(MobileCore.save)
	apply_settings()
	if run_mode == "rift" and not RushChallenges.rift_open(MobileCore.save): run_mode = "sprint"
	if not RushChallenges.available(MobileCore.save, run_mode, stage): stage = 0
	go_home()
	if account_open: hud.account_page()
	else: hud.home()
