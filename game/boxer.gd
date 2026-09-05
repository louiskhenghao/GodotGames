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

func build(is_hero: bool, elite: bool = false) -> void:
	hero = is_hero
	body = Node3D.new()
	add_child(body)
	torso = MeshInstance3D.new()
	body.add_child(torso)
	head = MeshInstance3D.new()
	body.add_child(head)
	head.position.y = 1.57
	for side in [-1, 1]:
		var arm := MeshInstance3D.new()
		body.add_child(arm)
		arm.position = Vector3(side * 0.37, 1.16, 0)
		arms.append(arm)
		var leg := MeshInstance3D.new()
		body.add_child(leg)
		leg.position = Vector3(side * 0.16, 0.57, 0)
		legs.append(leg)
	warning = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.88
	ring.outer_radius = 1.0
	ring.rings = 32
	ring.ring_segments = 6
	warning.mesh = ring
	warning.material_override = material(Color("ff604f"))
	warning.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	warning.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(warning)
	warning.position.y = 0.12
	warning.visible = false
	configure("hero" if hero else ("brute" if elite else "rookie"))

func configure(kind: String) -> void:
	role = kind
	var meshes := RushModelFactory.fighter(role, gold)
	torso.mesh = meshes.torso
	head.mesh = meshes.head
	for i in 2:
		arms[i].mesh = meshes["arm" + str(-1 if i == 0 else 1)]
		legs[i].mesh = meshes["leg" + str(-1 if i == 0 else 1)]
	scale = Vector3.ONE * {"hero": 0.9, "rookie": 0.77, "runner": 0.65, "brute": 1.02, "boss": 1.45}.get(role, 0.77)
	attack_timer = 0.7
	windup = 0
	burn = 0
	frost = 0
	dot_clock = 0
	knockback = Vector3.ZERO
	punch_time = 0
	hit_time = 0
	phase = randf() * TAU
	warning.visible = false
	visible = true
	active = true

func animate(delta: float, moving: bool) -> void:
	phase += delta * (13 if moving else 3)
	body.position.y = absf(sin(phase)) * 0.055 if moving else sin(phase) * 0.018
	punch_time = maxf(0, punch_time - delta)
	hit_time = maxf(0, hit_time - delta)
	var curve := sin(punch_time / 0.26 * PI)
	body.rotation.y = curve * (0.22 if alternate else -0.22)
	body.rotation.x = -hit_time * 0.9
	head.rotation.z = sin(phase * 0.5) * 0.035
	for i in 2:
		legs[i].rotation.x = sin(phase + i * PI) * 0.43 if moving else 0
		var strike := curve if (i == 0) == alternate else curve * 0.13
		arms[i].position.z = -strike * 0.63
		arms[i].rotation.x = -strike * 0.28 - 0.1
		arms[i].rotation.z = sin(phase + i) * 0.035

func face(direction: Vector3) -> void:
	if direction.length_squared() > 0.001: rotation.y = atan2(-direction.x, -direction.z)

func punch() -> void:
	alternate = not alternate
	punch_time = 0.26

func set_gold(enabled: bool) -> void:
	if gold == enabled: return
	gold = enabled
	var meshes := RushModelFactory.fighter(role, gold)
	for i in 2: arms[i].mesh = meshes["arm" + str(-1 if i == 0 else 1)]
