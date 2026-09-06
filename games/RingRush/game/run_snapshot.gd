class_name RushRunSnapshot
extends RefCounted
## JSON-safe resumable state. Transient visual effects are intentionally rebuilt empty.
const NUMBERS := ["stage","hp","max_hp","damage","reach","move_speed","cooldown","attack_clock","spawn_clock","elapsed","remaining","wave","kills","run_coins","level","xp","xp_needed","nova_clock","orbit_clock","rerolls","dash_clock","special_charge","combo","combo_clock","technique_clock","completed_waves"]
static func vector(v: Vector3) -> Array: return [v.x,v.y,v.z]
static func unpack(v: Array) -> Vector3: return Vector3(v[0],v[1],v[2])
static func capture(game: Node3D) -> Dictionary:
	var state := {"version":1,"knocked_out":game.mode=="defeat","revive_used":game.revive_used,"protection":game.invulnerable,"run_mode":game.run_mode,"character":game.player.character_id,"technique":game.technique_id,"ranks":game.ranks.duplicate(),"position":vector(game.player.position),"rotation":game.player.rotation.y,"boss_spawned":game.boss_spawned,"boss_defeated":game.boss_defeated,"upgrade":game.mode=="upgrade","options":[],"enemies":[],"pickups":[],"director":{"number":game.director.number,"target":game.director.target,"quota":game.director.quota,"spawned":game.director.spawned,"rest":game.director.rest,"clearing":game.director.clearing}}
	state.support=game.support.snapshot()
	state.arsenal=game.arsenal.timers.duplicate()
	state.ultimate=game.ultimate.snapshot()
	state.growth=game.growth.duplicate(true)
	state.records=game.records.duplicate(true)
	for key in NUMBERS: state[key]=game.get(key)
	for entry in game.options: state.options.append(entry.id)
	for enemy in game.enemies:
		state.enemies.append({"role":enemy.role,"position":vector(enemy.position),"health":enemy.health,"max_health":enemy.max_health,"speed":enemy.speed,"attack_timer":enemy.attack_timer,"windup":enemy.windup,"burn":enemy.burn,"burn_damage":enemy.burn_damage,"frost":enemy.frost,"dot_clock":enemy.dot_clock})
		if enemy.role=="boss":state.enemies[-1].boss_combat=enemy.encounter.snapshot()
	for pickup in game.pickups: state.pickups.append(vector(pickup.position))
	return state
static func valid(state: Variant) -> bool:
	if not state is Dictionary or state.get("version") != 1: return false
	if state.has("support") and not RushSupportCombat.valid(state.support):return false
	if state.has("arsenal") and not RushRunArsenal.valid(state.arsenal):return false
	if state.has("ultimate") and not RushUltimates.valid(state.ultimate):return false
	for key in NUMBERS:
		if not (state.get(key) is float or state.get(key) is int) or not is_finite(float(state[key])): return false
	for key in ["boss_spawned","boss_defeated","upgrade"]:
		if not state.get(key) is bool: return false
	for key in ["knocked_out", "revive_used"]:
		if state.has(key) and not state[key] is bool: return false
	if state.has("protection"):
		if not (state.protection is int or state.protection is float) or not is_finite(float(state.protection)) or state.protection < 0: return false
	for group in ["growth","records"]:
		if state.has(group):
			if not state[group] is Dictionary:return false
			for key in state[group]:
				var number=state[group][key]
				if group=="growth" and key=="contract":
					if not number is bool:return false
				elif not (number is int or number is float) or not is_finite(float(number)) or number<0:return false
	if state.has("growth"):
		for key in ["enemy_hp","enemy_damage","enemy_speed","cooldown","coins"]:
			if state.growth.has(key) and (state.growth[key]<.5 or state.growth[key]>3):return false
	if state.has("growth") and (state.growth.get("skill_level",1)<1 or state.growth.get("skill_level",1)>10 or state.growth.get("grit",0)>.18):return false
	if not (state.get("rotation") is int or state.get("rotation") is float): return false
	if not state.get("character") is String or RushRoster.character(state.character).id!=state.character: return false
	if not state.get("technique") is String or RushRoster.move(state.technique).id!=state.technique: return false
	if (state.hp <= 0 and not state.get("knocked_out",false)) or state.max_hp <= 0 or state.xp_needed <= 0: return false
	if state.stage < 0 or state.stage >= RushBalance.STAGES.size(): return false
	if (state.stage==5)!=(state.get("run_mode")=="rift"):return false
	if not state.get("director") is Dictionary or not state.get("ranks") is Dictionary: return false
	for key in ["number","target","quota","spawned","rest"]:
		if not (state.director.get(key) is int or state.director.get(key) is float): return false
	if not state.director.get("clearing") is bool: return false
	if not state.get("enemies") is Array or state.enemies.size()>RushBalance.MAX_ENEMIES: return false
	if not state.get("pickups") is Array or state.pickups.size()>64: return false
	if not _vector_valid(state.get("position")): return false
	for enemy in state.enemies:
		if not enemy is Dictionary or not _vector_valid(enemy.get("position")): return false
		if enemy.get("role") not in ["rookie","runner","brute","boss","charger","spark","guard","bone","revenant","hexer","drone","spitter","hound","wisp","stinger","sentry"]: return false
		if enemy.has("boss_combat") and (enemy.role!="boss" or not RushBossCombat.valid(enemy.boss_combat)):return false
		if enemy.role in ["bone","revenant","hexer"] and state.get("run_mode")!="rift":return false
		for key in ["health","max_health","speed","attack_timer","windup","burn","burn_damage","frost","dot_clock"]:
			if not (enemy.get(key) is int or enemy.get(key) is float): return false
	for position in state.pickups:
		if not _vector_valid(position): return false
	return state.get("run_mode") in ["classic","sprint","survival30","onslaught50","ladder","hell","blitz","bossrush","rift"] and state.get("options") is Array
static func _vector_valid(value: Variant) -> bool:
	if not value is Array or value.size()!=3: return false
	for n in value:
		if not (n is int or n is float): return false
	return true
static func restore(game: Node3D, state: Dictionary) -> void:
	game._clear_combat()
	game.growth=state.get("growth",RushGrowth.legacy(game.get_node("/root/MobileCore").save)).duplicate(true)
	game.records=state.get("records",{}).duplicate(true)
	for key in NUMBERS: game.set(key,state[key])
	game.run_mode=state.run_mode
	game.director.begin(state.run_mode)
	for key in ["number","target","quota","spawned","rest","clearing"]: game.director.set(key,state.director[key])
	game.ranks=state.ranks.duplicate()
	game.technique_id=state.technique
	game.player.set_character(state.character)
	game.player.position=unpack(state.position)
	game.player.rotation.y=state.rotation
	if state.has("support"):game.support.restore(state.support,game.player.position)
	if state.has("arsenal"):game.arsenal.timers=state.arsenal.duplicate()
	if state.has("ultimate"):game.ultimate.restore(state.ultimate)
	game.arena.set_stage(game.stage)
	game._play_music(game.run_mode)
	game._reset_combat_camera()
	for data in state.enemies:
		var enemy: RushBoxer = game._spawn(unpack(data.position),RushEncounterRoster.adapt(game.stage,data.role))
		for key in ["health","max_health","speed","attack_timer","windup","burn","burn_damage","frost","dot_clock"]: enemy.set(key,data[key])
		enemy.windup=0
		enemy.attack_timer=maxf(.8,enemy.attack_timer)
		if enemy.role=="boss":
			game.boss=enemy
			enemy.encounter.restore(data.get("boss_combat",{}),enemy)
	for i in state.pickups.size():
		var pickup: MeshInstance3D = game.pickup_pool[i]
		pickup.position=unpack(state.pickups[i])
		pickup.visible=true
		game.pickups.append(pickup)
	game.boss_spawned=state.boss_spawned
	game.boss_defeated=state.boss_defeated
	game.invulnerable=maxf(.8,float(state.get("protection",.8)))
	game.revive_used=state.get("revive_used",false)
	game.options.clear()
	for id in state.options:
		var entry := RushBalance.ability(id)
		if not entry.is_empty(): game.options.append(entry)
	if state.get("knocked_out",false):
		game.mode="defeat"
		game.hud.revive_offer()
	elif state.upgrade and not game.options.is_empty():
		game.mode="upgrade"
		game.hud.abilities(game.options)
	else:
		game.mode="paused"
		game.hud.paused()
