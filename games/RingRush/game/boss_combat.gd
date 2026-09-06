class_name RushBossCombat
extends RefCounted
## Boss rules belong to RingRush; presentation uses the shared bounded VFX pool.
const DANGER:=Color("ff665c")
const BREAK:=Color("ffd36e")
const COUNTER:=Color("69f6d1")
const BREAK_WINDOW:=.42
const DODGE_WINDOW:=.30
var feedback:=""
var feedback_time:=0.0
var phase:=1
var sequence:=0
var cooldown:=1.1
var windup:=0.0
var duration:=1.0
var roar:=0.0
var stagger:=0.0
var counter_open:=0.0
var attack_kind:="slam"
var target:=Vector3.ZERO
var origin:=Vector3.ZERO
var radius:=2.6
var rush:=0.0
var rush_direction:=Vector3.ZERO
var rush_hit:=false
var followup:=false
var break_armed:=false
var dodge_rewarded:=false

func breakable() -> bool:
	return windup>0 and windup<=BREAK_WINDOW and stagger<=0 and roar<=0

func arm_break() -> void:
	break_armed=breakable()

func caption() -> String:
	if roar>0:return "PHASE II / DOUBLE STRIKE"
	if feedback_time>0:return feedback
	if counter_open>0:return "COUNTER READY / CLOSE IN"
	if stagger>0:return "GUARD BROKEN"
	if breakable():return "BREAK! / HIT WITH SKILL"
	if windup>0 or rush>0:return {"slam":"SLAM / MOVE OUT","bolt":"STRIKE / MOVE OUT","charge":"CHARGE / SIDESTEP"}[attack_kind]
	return "GOLD: SKILL / LATE DODGE: COUNTER"

func tint() -> Color:
	if counter_open>0 or stagger>0:return COUNTER
	return BREAK if breakable() else DANGER

func update(game:Node3D, actor:Node3D, delta:float) -> void:
	if phase==1 and actor.health<=actor.max_health*.5:
		phase=2
		_cancel(actor)
		roar=.95
		cooldown=.3
		game.vfx.ring(actor.position,DANGER,3.6,.8,true)
		game.audio.play(load("res://assets/ko.wav"),.75)
		game.shake=maxf(game.shake,.18)
	feedback_time=maxf(0,feedback_time-delta)
	counter_open=maxf(0,counter_open-delta)
	if roar>0 or stagger>0:
		roar=maxf(0,roar-delta)
		stagger=maxf(0,stagger-delta)
		actor.animate(delta,false)
		return
	if rush>0:
		var before:Vector3=actor.position
		actor.position=RushArenaLayout.move(before,rush_direction*10*delta,game.stage,.5)
		var closest:=Geometry3D.get_closest_point_to_segment(game.player.position,before,actor.position)
		if not rush_hit and closest.distance_to(game.player.position)<1.05:
			rush_hit=true
			game._take_damage(24 if phase==2 else 20)
		game.vfx.stroke(before+Vector3.UP*.15,actor.position+Vector3.UP*.15,DANGER,.18,.12)
		rush=maxf(0,rush-delta)
		if actor.position.distance_to(before)<.005:rush=0
		actor.animate(delta,true)
		if rush<=0:_recover(actor)
		return
	if windup>0:
		windup=maxf(0,windup-delta)
		actor.windup=windup
		_show_warning(game,actor)
		actor.animate(delta,false)
		if windup<=0:_resolve(game,actor)
		return
	cooldown=maxf(0,cooldown-delta)
	var distance:float=actor.position.distance_to(game.player.position)
	if cooldown<=0 and followup:
		followup=false
		_begin(game,actor,"bolt" if attack_kind!="bolt" else "charge")
		return
	var base:String=["slam","charge","bolt"][(game.stage+(game.wave if game.run_mode=="bossrush" else 0))%3]
	if game.run_mode=="rift":base="bolt"
	var kind:String=base if phase==1 or sequence%2==0 else ["slam","charge","bolt"][(["slam","charge","bolt"].find(base)+1)%3]
	var trigger:float=2.8 if kind=="slam" else 6.2
	if cooldown<=0 and distance<=trigger:
		followup=phase==2
		_begin(game,actor,kind)
		return
	var moving:bool=distance>(1.9 if kind=="slam" else 4.1)
	if moving:
		var direction:=RushArenaLayout.steer(actor.position,game.player.position,game.stage)
		actor.position=RushArenaLayout.move(actor.position,direction*actor.speed*(1.18 if phase==2 else 1.0)*(.65 if actor.frost>0 else 1.0)*delta,game.stage,.5)
		actor.face(direction)
	actor.animate(delta,moving)

func _begin(game:Node3D, actor:Node3D, kind:String) -> void:
	attack_kind=kind
	sequence+=1
	target=game.player.position
	origin=actor.position
	radius=(3.25 if phase==2 else 2.6) if kind=="slam" else 1.65
	duration={"slam":1.05,"charge":.95,"bolt":1.15}[kind]
	windup=duration
	actor.windup=windup
	break_armed=false
	dodge_rewarded=false
	actor.face(target-actor.position)
	_show_warning(game,actor)

func _show_warning(game:Node3D,actor:Node3D) -> void:
	actor.warning.visible=true
	actor.warning.material_override.albedo_color=tint()
	actor.warning.global_position=(target if attack_kind=="bolt" else origin)+Vector3.UP*.14
	var size:float=(1.15 if attack_kind=="charge" else radius)/actor.scale.x
	actor.warning.scale=Vector3(size,.08,size)
	if attack_kind=="charge":
		var end:=origin+(target-origin).normalized()*5.2
		var side:Vector3=(end-origin).normalized().cross(Vector3.UP)*1.05
		for offset in [side,-side]:game.vfx.stroke(origin+offset+Vector3.UP*.12,end+offset+Vector3.UP*.12,tint(),.09,.09)

func _resolve(game:Node3D,actor:Node3D) -> void:
	actor.warning.visible=false
	actor.windup=0
	break_armed=false
	actor.punch()
	match attack_kind:
		"slam":
			actor.slam_time=.45
			game.vfx.quake(origin,DANGER,radius)
			game.audio.play(load("res://assets/slam.wav"),.85)
			if threatens(game.player.position):game._take_damage(28 if phase==2 else 22)
		"bolt":
			game.vfx.lightning(target+Vector3.UP*5,target,DANGER)
			game.vfx.ring(target,DANGER,radius,.45,true)
			game.audio.play(load("res://assets/electric.wav"),.8)
			if threatens(game.player.position):game._take_damage(24 if phase==2 else 18)
		"charge":
			rush=.52
			rush_direction=(target-origin).normalized()
			rush_hit=false
	if rush<=0:_recover(actor)

func threatens(point:Vector3) -> bool:
	if attack_kind=="charge":
		return Geometry3D.get_closest_point_to_segment(point,origin,origin+(target-origin).normalized()*5.2).distance_to(point)<1.05
	return point.distance_to(target if attack_kind=="bolt" else origin)<radius

func on_dodge(game:Node3D,actor:Node3D) -> bool:
	if dodge_rewarded or not threatens(game.player.position):return false
	if not (windup>0 and windup<=DODGE_WINDOW):return false
	dodge_rewarded=true
	counter_open=2.2
	game.vfx.ring(game.player.position,COUNTER,1.3,.45,true)
	game.audio.play(load("res://assets/whoosh.wav"),1.5)
	return true

func damage_multiplier(game:Node3D,actor:Node3D,direct:bool,skill:bool) -> float:
	if counter_open>0 and (direct or skill):
		_cancel(actor)
		stagger=.9
		cooldown=1.2
		game.special_charge=minf(100,game.special_charge+8)
		game.record_action("perfect_counters")
		_feedback(game,actor,"COUNTER! / 2.5x / ENERGY +8")
		return 2.5
	if skill and break_armed and breakable():
		_cancel(actor)
		stagger=1.65
		cooldown=1.2
		game.special_charge=minf(100,game.special_charge+12)
		game.technique_clock*=.65
		game.record_action("guard_breaks")
		_feedback(game,actor,"GUARD BREAK! / ENERGY +12")
		return 1.6
	return 1.0

func _feedback(game:Node3D,actor:Node3D,text:String) -> void:
	game.vfx.ring(actor.position,COUNTER,2.3,.5,true)
	game.vfx.strike(actor.position,Vector3.FORWARD,BREAK)
	game.audio.play(load("res://assets/slam.wav"),1.3)
	feedback=text
	feedback_time=1.25
	game.hit_stop=maxf(game.hit_stop,.07)
	game.haptic(30)

func _cancel(actor:Node3D) -> void:
	windup=0
	rush=0
	followup=false
	break_armed=false
	counter_open=0
	actor.windup=0
	actor.launch_time=0
	actor.warning.visible=false
	actor.warning.position=Vector3.UP*.12

func _recover(actor:Node3D) -> void:
	actor.warning.position=Vector3.UP*.12
	cooldown=.5 if followup else (1.85 if phase==2 else 2.2)

func snapshot() -> Dictionary:
	return {"phase":phase,"sequence":sequence}

static func valid(data:Variant) -> bool:
	if not data is Dictionary:return false
	for key in ["phase","sequence"]:
		if not (data.get(key) is int or data.get(key) is float):return false
		if not is_finite(float(data[key])) or float(data[key])!=floorf(float(data[key])):return false
	return data.phase>=1 and data.phase<=2 and data.sequence>=0 and data.sequence<=100000

func restore(data:Dictionary,actor:Node3D) -> void:
	phase=int(data.get("phase",2 if actor.health<=actor.max_health*.5 else 1))
	sequence=int(data.get("sequence",0))
	# Resume with fresh readable telegraphs; never replay a partial strike or reward window.
	_cancel(actor)
	roar=0
	stagger=0
	cooldown=1.25
