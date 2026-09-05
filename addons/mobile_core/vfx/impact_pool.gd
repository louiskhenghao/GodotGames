class_name CoreImpactPool
extends Node3D
## Fixed pools; instanced particles use a single draw call on Compatibility/mobile.
@export var capacity := 192
var particles: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var numbers: Array[Dictionary] = []
var cursor := 0
var ring_cursor := 0
var text_cursor := 0
var enabled := true
var instanced: MultiMeshInstance3D

func _ready() -> void:
	instanced = MultiMeshInstance3D.new()
	instanced.multimesh = MultiMesh.new()
	instanced.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	instanced.multimesh.use_colors = true
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.10
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	instanced.multimesh.mesh = mesh
	instanced.multimesh.instance_count = capacity
	instanced.multimesh.custom_aabb = AABB(Vector3(-15, -2, -15), Vector3(30, 15, 30))
	instanced.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instanced)
	for i in capacity:
		particles.append({"position": Vector3.ZERO, "velocity": Vector3.ZERO, "life": 0.0})
		_hide(i)
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.92
	ring_mesh.outer_radius = 1.0
	ring_mesh.rings = 40
	ring_mesh.ring_segments = 4
	for i in 12:
		var node := MeshInstance3D.new()
		node.mesh = ring_mesh
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		node.material_override = m
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visible = false
		add_child(node)
		rings.append({"node": node, "life": 0.0, "duration": 0.5, "radius": 3.0})
	for i in 16:
		var node := Label3D.new()
		node.font_size = 42
		node.pixel_size = 0.012
		node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		node.outline_size = 7
		node.outline_modulate = Color("152233")
		node.no_depth_test = true
		node.visible = false
		add_child(node)
		numbers.append({"node": node, "life": 0.0})

func _hide(index: int) -> void:
	instanced.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(0, -100, 0)))

func clear() -> void:
	for i in capacity:
		particles[i].life = 0
		_hide(i)
	for p in rings:
		p.life = 0
		p.node.visible = false
	for p in numbers:
		p.life = 0
		p.node.visible = false

func burst(origin: Vector3, color: Color, count: int = 10, strength: float = 1.0) -> void:
	if not enabled: return
	for i in mini(count, capacity):
		var p := particles[cursor]
		p.position = origin
		p.life = randf_range(0.20, 0.45)
		p.velocity = Vector3(randf_range(-3, 3), randf_range(2, 5), randf_range(-3, 3)) * strength
		instanced.multimesh.set_instance_color(cursor, color)
		cursor = (cursor + 1) % capacity

func beam(from: Vector3, to: Vector3, color: Color) -> void:
	if not enabled: return
	for i in 12:
		var p := particles[cursor]
		p.position = from.lerp(to, float(i) / 11)
		p.life = 0.18
		p.velocity = Vector3.ZERO
		instanced.multimesh.set_instance_color(cursor, color)
		cursor = (cursor + 1) % capacity

func ring(origin: Vector3, color: Color, radius: float, duration: float = 0.45) -> void:
	if not enabled: return
	var p := rings[ring_cursor]
	ring_cursor = (ring_cursor + 1) % rings.size()
	p.node.position = origin + Vector3.UP * 0.16
	p.node.material_override.albedo_color = color
	p.node.visible = true
	p.node.scale = Vector3(0.1, 0.12, 0.1)
	p.life = duration
	p.duration = duration
	p.radius = radius

func damage_number(at: Vector3, value: int, critical: bool = false) -> void:
	if not enabled: return
	var p := numbers[text_cursor]
	text_cursor = (text_cursor + 1) % numbers.size()
	p.node.text = str(value) + ("!" if critical else "")
	p.node.modulate = Color("ffcf67") if critical else Color("fff1d5")
	p.node.position = at + Vector3(randf_range(-0.15, 0.15), 1.8, 0)
	p.node.visible = true
	p.life = 0.6

func _process(delta: float) -> void:
	for i in capacity:
		var p := particles[i]
		if p.life <= 0: continue
		p.life -= delta
		if p.life <= 0:
			_hide(i)
			continue
		p.velocity.y -= delta * 10
		p.position += p.velocity * delta
		var size := clampf(p.life * 5, 0.1, 1.7)
		instanced.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * size), p.position))
	for p in rings:
		if p.life <= 0: continue
		p.life -= delta
		p.node.visible = p.life > 0
		var size: float = lerpf(0.1, p.radius, 1 - p.life / p.duration)
		p.node.scale = Vector3(size, maxf(0.02, p.life * 0.2), size)
	for p in numbers:
		if p.life <= 0: continue
		p.life -= delta
		p.node.position.y += delta * 1.2
		p.node.visible = p.life > 0
