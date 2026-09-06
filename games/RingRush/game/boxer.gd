class_name RushBoxer
extends Node3D
var health := 24.0
var max_health := 24.0
var speed := 1.8
var attack_timer := 0.0
var windup := 0.0
var encounter:RushBossCombat
var burn := 0.0
var burn_damage := 0.0
var frost := 0.0
var dot_clock := 0.0
var knockback := Vector3.ZERO
var body: Node3D
var head: MeshInstance3D
var arms: Array[MeshInstance3D] = []
var legs: Array[MeshInstance3D] = []
var torso: MeshInstance3D
var warning: MeshInstance3D
var phase := 0.0
var punch_time := 0.0
var hit_time := 0.0
var hero := false
var gold := false
var role := "rookie"
var boss_appearance:=""
var alternate := false
var active := false
var generation:=0
var creature_model:RushCreatureModel
var dying:=false
var death_clock:=0.0
var death_push:=Vector3.ZERO
var flash_time:=0.0
static var flash_material:StandardMaterial3D

static func material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	return m

static func box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material(color)
	parent.add_child(node)
	node.position = at
	return node

static func sphere(parent: Node3D, size: float, at: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2
	mesh.radial_segments = 12
	mesh.rings = 6
	node.mesh = mesh
	node.material_override = material(color)
	parent.add_child(node)
	node.position = at
	return node

const HUMAN = preload("res://assets/fighters/boxer.gltf")
var crowd_mesh: MeshInstance3D
var crowd_clip := ""
var crowd_time := 0.0
static var crowd_library: RushCrowdLibrary
static var variants:Dictionary={}
var crowd_poses:RushCrowdLibrary
var attack_target:=Vector3.ZERO
var rush_time:=0.0
var rush_direction:=Vector3.ZERO
var rush_hit:=false
var skeleton: Skeleton3D
var animator: AnimationPlayer
var layered_animation:RushFighterAnimation
var skin_mesh: MeshInstance3D
var outfit: MeshInstance3D
var gloves: Array[MeshInstance3D] = []
var character_id := "atlas"
var mech_head:Node3D
var mech_arms:Array[Node3D]=[]
var mech_fists:Array[Node3D]=[]
var authoring_creature:=false # Only the offline crowd-baking tool sets this.
var slam_time := 0.0
var spin_time := 0.0
var launch_time := 0.0
var animation_clock := 0.0
static var outfits: Dictionary = {}

func build(is_hero: bool, elite: bool = false) -> void:
	hero = is_hero
	if not hero:
		if crowd_library == null: crowd_library=load("res://assets/fighters/crowd.res")
		if variants.is_empty():
			variants["raven"]=load("res://assets/fighters/crowd_raven.res")
			variants["titan"]=load("res://assets/fighters/crowd_titan.res")
		crowd_poses=crowd_library
		body=Node3D.new()
		body.rotation.y=PI
		add_child(body)
		creature_model=RushCreatureModel.new()
		body.add_child(creature_model)
		creature_model.visible=false
		RushCreatureModel.prewarm()
		crowd_mesh=MeshInstance3D.new()
		body.add_child(crowd_mesh)
		crowd_mesh.mesh=crowd_poses.clips.Idle[0]
		var skin_material := material(Color.WHITE)
		skin_material.albedo_texture=load("res://assets/fighters/T_Superhero_Male_Dark.png")
		skin_material.shading_mode=BaseMaterial3D.SHADING_MODE_PER_VERTEX
		crowd_mesh.set_surface_override_material(0,skin_material)
	else:
		_build_hero()
	warning = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = .88
	ring.outer_radius = 1.0
	ring.rings = 32
	ring.ring_segments = 4
	warning.mesh = ring
	warning.material_override = material(Color("ff604f"))
	warning.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	warning.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(warning)
	warning.position.y = .12
	configure("hero" if hero else ("brute" if elite else "rookie"))

static func clothing(source: Mesh, shirt: bool, style_id: String = "") -> ArrayMesh:
	var key := str(source.get_instance_id())+str(shirt)+style_id
	if outfits.has(key): return outfits[key]
	var arrays := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var chosen := PackedInt32Array()
	var colors := PackedColorArray()
	for v in vertices:
		var shorts := v.y > .60 and v.y < 1.06
		var boots := v.y < .22
		var trim := (v.y > 1.0 and v.y < 1.07) or (v.y > .60 and v.y < .65) or (v.y > .18 and v.y < .22)
		colors.append(Color("f2e4c5") if trim else (Color.WHITE if shorts else (Color("1b2231") if boots else Color("272f42"))))
	for i in range(0,indices.size(),3):
		var v := (vertices[indices[i]]+vertices[indices[i+1]]+vertices[indices[i+2]])/3
		var cover := (v.y > .60 and v.y < 1.065) or v.y < .22 or (v.y > 1.765 and v.z < .045)
		if shirt and v.y >= 1.06 and v.y < 1.56: cover = true
		if style_id in ["raven","volt","sol"] and v.y<1.05:cover=true
		if cover: chosen.append_array(PackedInt32Array([indices[i],indices[i+1],indices[i+2]]))
	for i in vertices.size(): vertices[i] += normals[i] * .016
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = chosen
	arrays[Mesh.ARRAY_COLOR] = colors
	# Imported extra UV channels use custom formats. The outfit only needs UV0/UV1
	# and vertex color; omit unused custom channels when rebuilding its surface.
	for slot in range(Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM3 + 1): arrays[slot] = null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	outfits[key] = mesh
	return mesh

func configure(kind: String, creature_boss:bool=false, appearance:String="") -> void:
	generation+=1
	dying=false
	death_clock=0
	flash_time=0
	_flash_target().material_overlay=null
	body.position=Vector3.ZERO
	body.rotation=Vector3(0,PI,0)
	if crowd_mesh!=null:_set_crowd_alpha(1.0)
	role = kind
	boss_appearance=appearance if kind=="boss" else ""
	if not hero:
		creature_model.visible=is_nonhuman()
		crowd_mesh.visible=not is_nonhuman()
		if is_nonhuman():
			creature_model.configure(boss_appearance if not boss_appearance.is_empty() else kind)
			creature_model.animate(0,false,0)
	attack_target=Vector3.ZERO
	rush_time=0
	rush_hit=false
	if not hero and not is_nonhuman():
		var variant:String="raven" if kind in ["runner","spark"] else ("titan" if kind in ["brute","boss","charger","guard"] else "atlas")
		if kind=="boss" and creature_boss:variant="hex"
		variant={"bone":"rattle","revenant":"shade","hexer":"hex"}.get(kind,variant)
		if variant!="atlas" and not variants.has(variant):variants[variant]=load("res://assets/fighters/crowd_"+variant+".res")
		crowd_poses=crowd_library if variant=="atlas" else variants[variant]
		crowd_mesh.mesh=crowd_poses.clips.Idle[0]
		var skin:StandardMaterial3D=crowd_mesh.get_surface_override_material(0)
		skin.albedo_texture=load("res://assets/fighters/kaykit/skeleton_texture.png") if variant in ["rattle","shade","hex"] else load("res://assets/fighters/T_Superhero_Female_Dark_BaseColor.png" if variant=="raven" else "res://assets/fighters/T_Superhero_Male_Dark.png")
	if hero and not is_creature() and not is_mech(): outfit.mesh = clothing(skin_mesh.mesh, character_id != "atlas",character_id)
	var tint: Color = RushRoster.character(character_id).color if hero else {"rookie":Color("d74f52"),"runner":Color("6886d6"),"brute":Color("c59245"),"boss":Color("8c63b3"),"charger":Color("ef624b"),"spark":Color("72ceff"),"guard":Color("59bfb2"),"bone":Color("e2d4a1"),"revenant":Color("c5a2ff"),"hexer":Color("9aedcf")}.get(role,Color("d74f52"))
	var cloth := material(tint)
	cloth.vertex_color_use_as_albedo = true
	if hero:
		if not is_creature() and not is_mech():outfit.material_override = cloth
	else:
		cloth.shading_mode=BaseMaterial3D.SHADING_MODE_PER_VERTEX
		crowd_mesh.set_surface_override_material(1,cloth)
	for glove in gloves:
		glove.material_override = material(Color("e9b741") if gold and hero else tint)
		glove.material_override.roughness = .42
	scale = Vector3.ONE * {"hero":1.10,"rookie":1.0,"runner":.94,"brute":1.18,"boss":1.42,"charger":1.12,"spark":.96,"guard":1.16}.get(role,1.0)
	if not boss_appearance.is_empty():scale=Vector3.ONE*1.9
	if hero and character_id == "titan": scale *= Vector3(1.15,1.07,1.1)
	if hero and character_id == "zephyr": scale *= Vector3(.92,1,.92)
	encounter=RushBossCombat.new() if role=="boss" else null
	warning.material_override.albedo_color=Color("ff604f")
	attack_timer = .7
	windup = 0
	burn = 0
	frost = 0
	dot_clock = 0
	knockback = Vector3.ZERO
	punch_time = 0
	hit_time = 0
	spin_time = 0
	slam_time = 0
	launch_time = 0
	phase = randf()*TAU
	warning.visible = false
	warning.position=Vector3.UP*.12
	visible = true
	active = true
	if hero:
		animator.play("Idle")
		animator.advance(0)
	else:
		crowd_time=0
		crowd_clip="Idle"
		crowd_mesh.mesh=crowd_poses.clips.Idle[0]

func set_character(id: String) -> void:
	if not authoring_creature:id=RushRoster.character(id).id
	if character_id != id:
		character_id = id
		if is_instance_valid(layered_animation):
			remove_child(layered_animation);layered_animation.queue_free();layered_animation=null
		remove_child(body)
		body.queue_free()
		gloves.clear();mech_arms.clear();mech_fists.clear()
		_build_hero()
	configure("hero")

func animate(delta: float, moving: bool) -> void:
	if flash_time>0:
		flash_time=maxf(0,flash_time-delta)
		if flash_time<=0:_flash_target().material_overlay=null
	phase += delta
	punch_time = maxf(0,punch_time-delta)
	hit_time = maxf(0,hit_time-delta)
	spin_time = maxf(0,spin_time-delta)
	slam_time = maxf(0,slam_time-delta)
	launch_time = maxf(0,launch_time-delta)
	body.position.y = sin(launch_time / .65 * PI) * .9 if launch_time > 0 else 0.0
	body.rotation.y = PI + (spin_time * 18 if spin_time > 0 else 0)
	if is_nonhuman():
		creature_model.animate(phase,moving,hit_time,punch_time)
		return
	var clip := "Punch_Cross" if alternate else "Punch_Jab"
	if hit_time > 0 and punch_time <= 0: clip = "Hit_Chest"
	elif punch_time <= 0: clip = "Jog_Fwd" if moving else "Idle"
	if hero and slam_time>0: clip="Punch_Cross"
	if not hero:
		if crowd_clip != clip: crowd_clip=clip; crowd_time=0
		crowd_time += delta*(1.7 if punch_time>0 else 1.0)
		var frames: Array = crowd_poses.clips[clip]
		var duration: float = crowd_poses.durations[clip]
		var frame := mini(frames.size()-1,int(fmod(crowd_time,duration)/duration*frames.size()))
		crowd_mesh.mesh=frames[frame]
		return
	if layered_animation==null:
		layered_animation=RushFighterAnimation.new();add_child(layered_animation);layered_animation.setup(animator)
		if punch_time>0:layered_animation.punch(alternate)
	layered_animation.pose(delta,moving)
	if is_mech():
		var head_pose:Transform3D=body.global_transform.affine_inverse()*skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("Head"))
		mech_head.position=head_pose.origin+Vector3.UP*.12
		for i in mech_arms.size():
			var strike:float=sin(clampf(punch_time/.34,0,1)*PI) if (alternate and i==0) or (not alternate and i==1) else 0.0
			mech_arms[i].rotation.x=-.15-strike*.55+(sin(phase*8+i*PI)*.18 if moving else 0)
			mech_fists[i].position.z=.20+strike*.55


func face(direction: Vector3) -> void:
	if direction.length_squared() > .001: rotation.y = atan2(-direction.x,-direction.z)

func punch() -> void:
	alternate = not alternate
	punch_time = .34
	if hero and is_instance_valid(layered_animation):layered_animation.punch(alternate)
	elif hero:animator.play("Punch_Cross" if alternate else "Punch_Jab",.06,1.7)

func set_gold(enabled: bool) -> void:
	gold = enabled
	var tint: Color = Color("e9b741") if gold else RushRoster.character(character_id).color
	for glove in gloves: glove.material_override.albedo_color = tint

func is_mech() -> bool:return character_id in ["aegis","ion","onyx"]

func is_creature() -> bool:
	return authoring_creature and character_id in ["rattle","shade","hex"]

func _build_hero() -> void:
	if is_mech():
		body=Node3D.new()
		body.add_child(load("res://assets/fighters/mechs/"+character_id+".scn").instantiate())
	elif is_creature():body=load("res://assets/fighters/kaykit/"+character_id+".scn").instantiate()
	else:body = (load("res://assets/fighters/boxer_female.gltf") if RushWardrobe.female(character_id) else HUMAN).instantiate()
	add_child(body)
	body.rotation.y = PI
	skeleton = body.find_child("Skeleton3D", true, false)
	animator = body.find_child("AnimationPlayer", true, false)
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if is_mech():
		skin_mesh=body.find_children("*","MeshInstance3D",true,false)[0]
		outfit=skin_mesh
		_build_mech_arms()
		_build_mech_head()
		_build_mech_weapon()
		return
	if is_creature():
		for mesh:MeshInstance3D in body.find_children("*","MeshInstance3D",true,false):
			if "Body" in mesh.name:skin_mesh=mesh;break
		outfit=skin_mesh
	else:
		skin_mesh = body.find_child("Superhero_Female" if RushWardrobe.female(character_id) else "SuperHero_Male", true, false)
		outfit = MeshInstance3D.new()
		outfit.skin = skin_mesh.skin
		outfit.skeleton = NodePath("..")
		skeleton.add_child(outfit)
	for side in ["l", "r"]:
		var attachment := BoneAttachment3D.new()
		skeleton.add_child(attachment)
		attachment.bone_name = ("hand." if is_creature() else "hand_") + side
		var glove := MeshInstance3D.new()
		glove.mesh = RushModelFactory.bake([
			RushModelFactory.piece("sphere", Vector3(.22,.27,.23), Vector3(0,.065,0), Color.WHITE),
			RushModelFactory.piece("box", Vector3(.16,.08,.17), Vector3(0,-.055,0), Color("f8efd9"))],12)
		attachment.add_child(glove)
		gloves.append(glove)
	if not is_creature():RushWardrobe.build(skeleton,character_id)

func hurt(flash:bool=true) -> void:
	hit_time=.23
	punch_time=0
	if hero and is_instance_valid(layered_animation):layered_animation.hurt()
	elif hero:animator.play("Hit_Chest",.045)
	else:crowd_clip=""
	if not flash:return
	if flash_material==null:
		flash_material=StandardMaterial3D.new()
		flash_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		flash_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		flash_material.albedo_color=Color(1,.64,.35,.48)
		flash_material.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED
	flash_time=.10
	_flash_target().material_overlay=flash_material

func is_nonhuman() -> bool:return not hero and (role in RushCreatureModel.TYPES or not boss_appearance.is_empty())

func _flash_target() -> MeshInstance3D:
	return creature_model.shell if is_nonhuman() else (skin_mesh if hero else crowd_mesh)

func begin_defeat(direction:Vector3) -> void:
	active=false
	dying=true
	death_clock=0
	death_push=direction*3.2
	warning.visible=false
	hit_time=0
	punch_time=0
	launch_time=0
	body.position=Vector3.ZERO
	body.rotation=Vector3(0,PI,0)
	_flash_target().material_overlay=null
	flash_time=0
	_set_crowd_alpha(1.0)

func animate_defeat(delta:float,stage:int) -> bool:
	if not dying:return true
	death_clock+=delta
	position=RushArenaLayout.move(position,death_push*exp(-death_clock*7)*delta,stage,.35)
	if is_nonhuman():
		creature_model.death_pose(death_clock)
	else:
		var frames:Array=crowd_poses.clips.Death01
		crowd_mesh.mesh=frames[mini(frames.size()-1,int(clampf(death_clock/.72,0,1)*(frames.size()-1)))]
	_set_crowd_alpha(1-clampf((death_clock-1.10)/.35,0,1))
	if death_clock>=1.45:
		finish_defeat()
		return true
	return false

func finish_defeat() -> void:
	dying=false
	death_clock=0
	visible=false
	if crowd_mesh!=null:
		_set_crowd_alpha(1.0)
		crowd_mesh.material_overlay=null

func _set_crowd_alpha(alpha:float) -> void:
	if is_nonhuman():
		creature_model.set_alpha(alpha)
		return
	# GeometryInstance3D.transparency is ignored by Compatibility/Mobile.
	# Fade each actor's existing materials; restore opaque rendering on reuse.
	if crowd_mesh==null:return
	for surface in 2:
		var mat:StandardMaterial3D=crowd_mesh.get_surface_override_material(surface)
		if mat==null:continue
		mat.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED if alpha>=1 else BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a=alpha

func _build_mech_arms() -> void:
	var tint:Color=RushRoster.character(character_id).color
	var heavy:float=1.18 if character_id=="aegis" else (1.08 if character_id=="onyx" else .88)
	for side in [-1,1]:
		var arm:=Node3D.new();body.add_child(arm);arm.position=Vector3(side*{"aegis":.77,"ion":.92,"onyx":.83}[character_id],1.3,0)
		var upper:=MeshInstance3D.new();upper.mesh=RushModelFactory.bake([
			RushModelFactory.piece("box",Vector3(.32,.24,.29)*heavy,Vector3.ZERO,tint.darkened(.15)),
			RushModelFactory.piece("cylinder",Vector3(.15,.38,.15)*heavy,Vector3(0,-.22,0),Color("4f6375")),
			RushModelFactory.piece("sphere",Vector3.ONE*.18,Vector3(0,-.39,0),Color("b6c9d6"))],12)
		arm.add_child(upper)
		var fist:=Node3D.new();arm.add_child(fist);fist.position=Vector3(0,-.29,.20)
		var gauntlet:=MeshInstance3D.new();gauntlet.mesh=RushModelFactory.bake([
			RushModelFactory.piece("box",Vector3(.22,.22,.32)*heavy,Vector3(0,0,-.08),Color("4a5c70")),
			RushModelFactory.piece("sphere",Vector3(.34,.32,.36)*heavy,Vector3(0,.07,.13),Color.WHITE),
			RushModelFactory.piece("box",Vector3(.22,.055,.05)*heavy,Vector3(0,.10,.30),Color("d9ffff"))],12)
		gauntlet.material_override=material(tint);fist.add_child(gauntlet);gloves.append(gauntlet)
		mech_arms.append(arm);mech_fists.append(fist)

func _build_mech_head() -> void:
	mech_head=Node3D.new();body.add_child(mech_head)
	var tint:Color=RushRoster.character(character_id).color
	var pieces:Array=[]
	var wide:float=.52 if character_id=="aegis" else .43
	pieces.append(RushModelFactory.piece("sphere",Vector3(wide,.43,.43),Vector3.ZERO,Color("536879")))
	pieces.append(RushModelFactory.piece("box",Vector3(wide*.86,.17,.07),Vector3(0,.015,.195),Color("101f31")))
	pieces.append(RushModelFactory.piece("box",Vector3(wide*.66,.045,.025),Vector3(0,.03,.24),tint.lightened(.45)))
	for side in [-1,1]:
		pieces.append(RushModelFactory.piece("box",Vector3(.09,.30,.28),Vector3(side*wide*.46,0,0),tint))
	if character_id=="ion":pieces.append(RushModelFactory.piece("box",Vector3(.055,.28,.1),Vector3(.13,.27,-.06),tint))
	if character_id=="onyx":
		for side in [-1,1]:pieces.append(RushModelFactory.piece("box",Vector3(.06,.22,.09),Vector3(side*.23,.23,-.08),tint))
	var model:=MeshInstance3D.new();model.mesh=RushModelFactory.bake(pieces,12);mech_head.add_child(model)
	var pose:Transform3D=body.global_transform.affine_inverse()*skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("Head"))
	mech_head.position=pose.origin+Vector3.UP*.12

func _build_mech_weapon() -> void:
	var parts:Array=[]
	var steel:=Color("344255")
	var light:Color=RushRoster.character(character_id).color
	if character_id=="aegis":
		parts.append(RushModelFactory.piece("box",Vector3(.34,.32,.4),Vector3(.48,1.13,.4),steel))
		for i in 6:
			var p:=RushModelFactory.piece("cylinder",Vector3(.075,.72,.075),Vector3(.48+cos(i*TAU/6)*.11,1.13+sin(i*TAU/6)*.11,.75),Color("768590"))
			p.rotation=Vector3(PI/2,0,0);parts.append(p)
	elif character_id=="ion":
		for side in [-1,1]:
			parts.append(RushModelFactory.piece("box",Vector3(.4,.46,.5),Vector3(side*.5,1.47,-.05),steel))
			for i in 3:parts.append(RushModelFactory.piece("sphere",Vector3(.11,.11,.16),Vector3(side*.5,1.32+i*.13,.23),light))
	else:
		for side in [-1,1]:
			parts.append(RushModelFactory.piece("cylinder",Vector3(.25,.63,.25),Vector3(side*.25,1.1,-.45),Color("8b4c51")))
			var p:=RushModelFactory.piece("cylinder",Vector3(.18,.5,.18),Vector3(side*.46,1.05,.63),steel)
			p.rotation=Vector3(PI/2,0,0);parts.append(p)
			parts.append(RushModelFactory.piece("sphere",Vector3(.14,.14,.12),Vector3(side*.46,1.05,.91),Color("ffb14d")))
	var model:=MeshInstance3D.new();model.name="RangedWeapon"
	model.mesh=RushModelFactory.bake(parts,10);body.add_child(model)
