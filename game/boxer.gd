class_name RushBoxer
extends Node3D
var health := 24.0
var max_health := 24.0
var speed := 1.8
var attack_timer := 0.0
var windup := 0.0
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
var alternate := false
var active := false

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
var skeleton: Skeleton3D
var animator: AnimationPlayer
var skin_mesh: MeshInstance3D
var outfit: MeshInstance3D
var gloves: Array[MeshInstance3D] = []
var character_id := "atlas"
var slam_time := 0.0
var spin_time := 0.0
var launch_time := 0.0
var animation_clock := 0.0
static var outfits: Dictionary = {}

func build(is_hero: bool, elite: bool = false) -> void:
	hero = is_hero
	if not hero:
		if crowd_library == null: crowd_library=load("res://assets/fighters/crowd.res")
		body=Node3D.new()
		body.rotation.y=PI
		add_child(body)
		crowd_mesh=MeshInstance3D.new()
		body.add_child(crowd_mesh)
		crowd_mesh.mesh=crowd_library.clips.Idle[0]
		var skin_material := material(Color.WHITE)
		skin_material.albedo_texture=load("res://assets/fighters/T_Superhero_Male_Dark.png")
		skin_material.shading_mode=BaseMaterial3D.SHADING_MODE_PER_VERTEX
		crowd_mesh.set_surface_override_material(0,skin_material)
	else:
		body = HUMAN.instantiate()
		add_child(body)
		body.rotation.y = PI
		skeleton = body.find_child("Skeleton3D", true, false)
		animator = body.find_child("AnimationPlayer", true, false)
		animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		skin_mesh = body.find_child("SuperHero_Male", true, false)
		outfit = MeshInstance3D.new()
		outfit.skin = skin_mesh.skin
		outfit.skeleton = NodePath("..")
		skeleton.add_child(outfit)
		for side in ["l", "r"]:
			var attachment := BoneAttachment3D.new()
			skeleton.add_child(attachment)
			attachment.bone_name = "hand_" + side
			var glove := MeshInstance3D.new()
			glove.mesh = RushModelFactory.bake([
				RushModelFactory.piece("sphere", Vector3(.22,.27,.23), Vector3(0,.065,0), Color.WHITE),
				RushModelFactory.piece("box", Vector3(.16,.08,.17), Vector3(0,-.055,0), Color("f8efd9"))],12)
			attachment.add_child(glove)
			gloves.append(glove)
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

static func clothing(source: Mesh, shirt: bool) -> ArrayMesh:
	var key := "shirt" if shirt else "shorts"
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
		if shirt and v.y >= 1.06 and v.y < 1.49: cover = true
		if cover: chosen.append_array(PackedInt32Array([indices[i],indices[i+1],indices[i+2]]))
	for i in vertices.size(): vertices[i] += normals[i] * .016
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = chosen
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	outfits[key] = mesh
	return mesh

func configure(kind: String) -> void:
	role = kind
	if hero: outfit.mesh = clothing(skin_mesh.mesh, false)
	var tint: Color = RushRoster.character(character_id).color if hero else {"rookie":Color("d74f52"),"runner":Color("6886d6"),"brute":Color("c59245"),"boss":Color("8c63b3")}.get(role,Color("d74f52"))
	var cloth := material(tint)
	cloth.vertex_color_use_as_albedo = true
	if hero: outfit.material_override = cloth
	else:
		cloth.shading_mode=BaseMaterial3D.SHADING_MODE_PER_VERTEX
		crowd_mesh.set_surface_override_material(1,cloth)
	for glove in gloves:
		glove.material_override = material(Color("e9b741") if gold and hero else tint)
		glove.material_override.roughness = .42
	scale = Vector3.ONE * {"hero":1.10,"rookie":1.0,"runner":.94,"brute":1.18,"boss":1.42}.get(role,1.0)
	if hero and character_id == "titan": scale *= Vector3(1.15,1.07,1.1)
	if hero and character_id == "zephyr": scale *= Vector3(.92,1,.92)
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
	visible = true
	active = true
	if hero:
		animator.play("Idle")
		animator.advance(0)
	else:
		crowd_time=0
		crowd_clip="Idle"
		crowd_mesh.mesh=crowd_library.clips.Idle[0]

func set_character(id: String) -> void:
	character_id = id
	configure("hero")

func animate(delta: float, moving: bool) -> void:
	phase += delta
	punch_time = maxf(0,punch_time-delta)
	hit_time = maxf(0,hit_time-delta)
	spin_time = maxf(0,spin_time-delta)
	slam_time = maxf(0,slam_time-delta)
	launch_time = maxf(0,launch_time-delta)
	body.position.y = sin(launch_time / .65 * PI) * .9 if launch_time > 0 else 0.0
	body.rotation.y = PI + (spin_time * 18 if spin_time > 0 else 0)
	var clip := "Punch_Cross" if alternate else "Punch_Jab"
	if hit_time > 0 and punch_time <= 0: clip = "Hit_Chest"
	elif punch_time <= 0: clip = "Jog_Fwd" if moving else "Idle"
	if hero and slam_time>0: clip="Jump_Land"
	if not hero:
		if crowd_clip != clip: crowd_clip=clip; crowd_time=0
		crowd_time += delta*(1.7 if punch_time>0 else 1.0)
		var frames: Array = crowd_library.clips[clip]
		var duration: float = crowd_library.durations[clip]
		var frame := mini(frames.size()-1,int(fmod(crowd_time,duration)/duration*frames.size()))
		crowd_mesh.mesh=frames[frame]
		return
	if animator.current_animation != clip:
		animator.play(clip,.10,1.7 if punch_time > 0 else 1.0)
	animator.advance(delta)

func face(direction: Vector3) -> void:
	if direction.length_squared() > .001: rotation.y = atan2(-direction.x,-direction.z)

func punch() -> void:
	alternate = not alternate
	punch_time = .34
	if hero: animator.play("Punch_Cross" if alternate else "Punch_Jab",.06,1.7)

func set_gold(enabled: bool) -> void:
	gold = enabled
	var tint: Color = Color("e9b741") if gold else RushRoster.character(character_id).color
	for glove in gloves: glove.material_override.albedo_color = tint
