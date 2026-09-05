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
var mode := "home"
var stage := 0
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
	for kind in ["hero", "rookie", "runner", "brute", "boss"]: RushModelFactory.fighter(kind)
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
	var recovered := RushProgress.recover(MobileCore.save)
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
	var low: bool = MobileCore.save.data.settings.get("low_quality", false)
	arena.set_quality(low)
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if low else Viewport.MSAA_2X
	if not vfx.enabled: vfx.clear()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if mode == "playing":
			checkpoint()
			pause_run()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if mode in ["playing", "paused", "upgrade"]: checkpoint()
		get_tree().quit()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE:
		if mode == "playing": pause_run()
		elif mode == "paused": resume_run()
	elif event.keycode == KEY_SPACE: dash()
	elif event.keycode == KEY_E: special()

func _clear_combat() -> void:
	for enemy in enemies:
		enemy.active = false
		enemy.visible = false
	for pickup in pickups: pickup.visible = false
	for glove in orbiters: glove.visible = false
	enemies.clear()
	pickups.clear()
	boss = null
	vfx.clear()

func go_home() -> void:
	mode = "home"
	_clear_combat()
	player.position = Vector3.ZERO
	player.scale = Vector3.ONE * 1.85
	player.face(Vector3(0.6, 0, 1))
	player.set_gold(MobileCore.save.data.entitlements.get("gold_gloves", false))
	podium.visible = true
	arena.showroom(true)
	# Lights and environment still affect the showroom while arena geometry is hidden.
	camera.position = Vector3(5, 3.7, 8)
	camera.look_at(Vector3(0, 1.75, 0))
	camera.position -= camera.basis.y * 0.85
	_frame_showroom()
	hud.home()

func select_stage(index: int) -> void:
	var unlocked := clampi(int(MobileCore.save.data.progress.get("unlocked_stage", 0)), 0, 2)
	if mode != "home" or index < 0 or index > unlocked: return
	stage = index
	hud.home()

func start_run() -> void:
	if MobileCore.save.unsupported_version:
		hud.toast("Update the game to use this newer save. Your file has been preserved.")
		return
	if mode not in ["home", "result"] or not MobileCore.commerce.pending.is_empty(): return
	if stage > int(MobileCore.save.data.progress.get("unlocked_stage", 0)): return
	if mode == "result" and not MobileCore.save.data.transactions.has(run_id): return
	if MobileCore.save.data.progress.has("pending_run") and RushProgress.recover(MobileCore.save) < 0:
		hud.toast("Save your previous reward first. Free storage and try again.")
		return
	_clear_combat()
	mode = "playing"
	arena.showroom(false)
	arena.set_stage(stage)
	podium.visible = false
	camera.position = camera_home
	camera.look_at(Vector3.ZERO)
	camera.size = 21.5
	player.configure("hero")
	max_hp = 100 + int(MobileCore.save.data.progress.get("health", 0)) * 10
	hp = max_hp
	damage = 18 + int(MobileCore.save.data.progress.get("power", 0)) * 3
	reach = 2.0
	move_speed = 4.3
	cooldown = 0.65
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
	rerolls = 1
	dash_clock = 0
	dash_time = 0
	invulnerable = 0
	special_charge = minf(50, int(MobileCore.save.data.progress.get("charge", 0)) * 10)
	combo = 0
	combo_clock = 0
	boss_spawned = false
	boss_defeated = false
	result_won = false
	checkpoint_clock = 15
	run_id = "run:" + Crypto.new().generate_random_bytes(16).hex_encode()
	player.position = Vector3.ZERO
	player.set_gold(MobileCore.save.data.entitlements.get("gold_gloves", false))
	checkpoint()
	hud.playing()

func checkpoint() -> void:
	if not run_id.is_empty():
		if not RushProgress.checkpoint(MobileCore.save, run_id, run_coins, stage, kills):
			hud.toast("Could not save checkpoint. Free storage and finish the round to retry.")

func pause_run() -> void:
	if mode != "playing": return
	mode = "paused"
	hud.paused()

func resume_run() -> void:
	if mode not in ["paused", "upgrade"]: return
	mode = "playing"
	hud.playing()

func finish_run(won: bool) -> void:
	if mode not in ["playing", "paused", "result"]: return
	if mode != "result":
		result_won = won
		if won: run_coins += int(RushBalance.STAGES[stage].reward)
	mode = "result"
	var saved := RushProgress.settle(MobileCore.save, run_id, run_coins, stage, kills, result_won)
	hud.result(result_won, saved)

func _process(delta: float) -> void:
	player.animate(delta, mode == "playing" and _movement().length_squared() > 0.01)
	if mode == "home":
		player.rotation.y += delta * 0.08
	elif mode == "playing":
		shake = maxf(0, shake - delta)
		camera.position = camera_home + Vector3(randf_range(-shake, shake), 0, randf_range(-shake, shake)) if vfx.enabled else camera_home
		hud.update_stats()

func _physics_process(delta: float) -> void:
	_simulate(delta)

func _simulate(delta: float) -> void:
	if mode != "playing": return
	elapsed += delta
	remaining = maxf(0, RushBalance.ROUND_SECONDS - elapsed)
	wave = mini(6, 1 + int(elapsed / 15))
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
	if elapsed >= 75 and not boss_spawned: _spawn_boss()
	if remaining <= 0 and boss_defeated:
		finish_run(true)
		return
	if elapsed >= 120:
		finish_run(false)
		return
	var movement := dash_direction if dash_time > 0 else _movement()
	player.position += movement * (16 if dash_time > 0 else move_speed) * delta
	player.position.x = clampf(player.position.x, -RushBalance.RING_LIMIT, RushBalance.RING_LIMIT)
	player.position.z = clampf(player.position.z, -RushBalance.RING_LIMIT, RushBalance.RING_LIMIT)
	if movement.length_squared() > 0.01: player.face(movement)
	spawn_clock -= delta
	if spawn_clock <= 0 and elapsed < 90:
		spawn_clock = maxf(0.40, 1.1 - wave * 0.11) / float(RushBalance.STAGES[stage].difficulty)
		if enemies.size() < RushBalance.MAX_ENEMIES - (0 if boss_spawned else 1):
			var angle := randf() * TAU
			_spawn(Vector3(cos(angle), 0, sin(angle)) * 6.1)
	attack_clock -= delta
	if attack_clock <= 0: _attack()
	_build_neighbors()
	for enemy: RushBoxer in enemies.duplicate():
		if enemy.active: _update_enemy(enemy, delta)
	if hp <= 0:
		finish_run(false)
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
	enemy.burn = maxf(0, enemy.burn - delta)
	enemy.frost = maxf(0, enemy.frost - delta)
	enemy.dot_clock -= delta
	if enemy.burn > 0 and enemy.dot_clock <= 0:
		enemy.dot_clock = 0.5
		_hit(enemy, enemy.burn_damage * 0.5, false, false)
		vfx.burst(enemy.position + Vector3.UP, Color("ff934b"), 3)
		if not enemy.active: return
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
		if distance > 0.9: enemy.position += (direction.normalized() * enemy.speed * slow + separation) * delta
		if distance < (2.3 if enemy.role == "boss" else 1.1) and enemy.attack_timer <= 0:
			enemy.windup = 0.9 if enemy.role == "boss" else 0.32
	enemy.position += enemy.knockback * delta
	enemy.knockback = enemy.knockback.move_toward(Vector3.ZERO, delta * 20)
	enemy.position.x = clampf(enemy.position.x, -6.25, 6.25)
	enemy.position.z = clampf(enemy.position.z, -6.25, 6.25)
	enemy.animate(delta, distance > 0.9 and enemy.windup <= 0)

func _take_damage(amount: float) -> void:
	if invulnerable > 0 or hp <= 0: return
	hp = maxf(0, hp - amount * (1 - rank_of("armor") * 0.1))
	invulnerable = 0.45
	player.hit_time = 0.18
	shake = 0.14
	combo = 0
	vfx.burst(player.position + Vector3.UP, Color("ff6e63"), 8)
	haptic(20)

func _update_skills(delta: float) -> void:
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
	invulnerable = 0.8
	shake = 0.20
	player.punch()
	vfx.ring(player.position, Color("ffcc70"), 5.2, 0.6)
	vfx.burst(player.position + Vector3.UP, Color("ffcf72"), 36, 1.8)
	_area_hit(5.2, damage * 4)
	audio.play(LEVEL_SOUND, 0.65)
	haptic(40)

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
		if not candidate.active:
			enemy = candidate
			break
	if enemy == null: return null
	if kind.is_empty():
		var roll := randf()
		kind = "brute" if wave >= 3 and roll < 0.18 else ("runner" if wave >= 2 and roll < 0.40 else "rookie")
	enemy.configure(kind)
	enemy.position = at
	var factor: float = RushBalance.STAGES[stage].difficulty
	enemy.max_health = (24 + wave * 3) * factor * {"rookie": 1.0, "runner": 0.75, "brute": 2.4, "boss": 18.0}.get(kind, 1)
	enemy.health = enemy.max_health
	enemy.speed = (1.3 + wave * 0.10) * {"rookie": 1.0, "runner": 1.6, "brute": 0.7, "boss": 0.8}.get(kind, 1)
	enemy.face(player.position - at)
	enemies.append(enemy)
	return enemy

func _spawn_boss() -> void:
	if enemies.size() >= RushBalance.MAX_ENEMIES:
		var removed: RushBoxer = enemies.pop_back()
		removed.active = false
		removed.visible = false
	boss = _spawn(Vector3(0, 0, -5.6), "boss")
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
	enemy.hit_time = 0.15
	enemy.knockback = (enemy.position - player.position).normalized() * (2.0 if enemy.role == "boss" else 6.0)
	if status:
		if rank_of("burn") > 0:
			enemy.burn = 3
			enemy.burn_damage = rank_of("burn") * 4
		if rank_of("frost") > 0: enemy.frost = 1.0 + rank_of("frost") * 0.6
	vfx.burst(enemy.position + Vector3.UP, Color("acdcff") if enemy.frost > 0 else Color("ffca62"), 5)
	vfx.damage_number(enemy.position, ceili(amount), critical)
	if enemy.health <= 0:
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
		enemy.active = false
		enemy.visible = false

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
	if mode != "upgrade": return
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
	resume_run()

func haptic(duration: int) -> void:
	if MobileCore.save.data.settings.get("haptics", true) and (OS.has_feature("android") or OS.has_feature("ios")):
		Input.vibrate_handheld(duration)

func _frame_showroom() -> void:
	if mode != "home": return
	var viewport := get_viewport().get_visible_rect().size
	camera.size = 6.8 * maxf(1.0, (viewport.x/viewport.y) / (540.0/960.0))
