class_name RushArena
extends Node3D
var key_light: DirectionalLight3D
var canvas: MeshInstance3D
var accents: Array[MeshInstance3D] = []
var audience: MultiMeshInstance3D

func _ready() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0a111d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("cadff3")
	env.ambient_light_energy = 0.30
	world.environment = env
	add_child(world)
	key_light = DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-58, -24, 0)
	key_light.light_color = Color("ffe7c0")
	key_light.light_energy = 0.85
	key_light.shadow_enabled = true
	key_light.directional_shadow_max_distance = 50
	add_child(key_light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30, 150, 0)
	fill.light_color = Color("7bdde5")
	fill.light_energy = 0.35
	add_child(fill)
	RushBoxer.box(self, Vector3(100, 0.2, 100), Vector3(0, -0.95, 0), Color("0c1422"))
	RushBoxer.box(self, Vector3(14.7, 0.7, 14.7), Vector3(0, -0.45, 0), Color("102838"))
	canvas = RushBoxer.box(self, Vector3(13.8, 0.12, 13.8), Vector3(0, -0.01, 0), Color("7c897f"))
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 4.48
	torus.outer_radius = 4.58
	torus.rings = 64
	torus.ring_segments = 4
	ring.mesh = torus
	ring.scale.y = 0.08
	ring.position.y = 0.085
	ring.material_override = RushBoxer.material(Color("586d66"))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	var trim_parts: Array = []
	for x in [-6.9, 6.9]:
		for z in [-6.9, 6.9]:
			trim_parts.append(RushModelFactory.piece("box", Vector3(0.28, 1.75, 0.28), Vector3(x, 0.72, z), Color("152b40")))
			for y in [0.42, 0.85, 1.25]:
				trim_parts.append(RushModelFactory.piece("sphere", Vector3(0.42, 0.32, 0.42), Vector3(x, y, z), Color("db795b") if x * z > 0 else Color("39b4ba")))
	for height in [0.45, 0.85, 1.25]:
		for edge in [-6.9, 6.9]:
			var color := Color("d79776") if height > 1.0 else Color("78969a")
			trim_parts.append(RushModelFactory.piece("box", Vector3(13.8, 0.05, 0.05), Vector3(0, height, edge), color))
			trim_parts.append(RushModelFactory.piece("box", Vector3(0.05, 0.05, 13.8), Vector3(edge, height, 0), color))
	var trim := MeshInstance3D.new()
	trim.mesh = RushModelFactory.bake(trim_parts)
	add_child(trim)
	for edge in [-7.35, 7.35]:
		accents.append(RushBoxer.box(self, Vector3(14.7, 0.055, 0.06), Vector3(0, -0.28, edge), Color("38c9ba")))
		accents.append(RushBoxer.box(self, Vector3(0.06, 0.055, 14.7), Vector3(edge, -0.28, 0), Color("38c9ba")))
	for accent in accents: accent.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var logo := Label3D.new()
	logo.text = "RING\nRUSH"
	logo.font = load("res://assets/fonts/BarlowCondensed-Bold.ttf")
	logo.font_size = 100
	logo.pixel_size = 0.019
	logo.outline_size = 0
	logo.modulate = Color("52665b")
	logo.rotation_degrees = Vector3(-90, 0, -45)
	logo.position = Vector3(0, 0.12, 0)
	add_child(logo)
	# All stadium chairs are instanced in one draw call.
	var chair_mesh := RushModelFactory.bake([
		RushModelFactory.piece("box", Vector3(0.72, 0.14, 0.68), Vector3.ZERO, Color("263a4c")),
		RushModelFactory.piece("box", Vector3(0.72, 0.65, 0.12), Vector3(0, 0.3, 0.3), Color("263a4c"))])
	var chairs := MultiMeshInstance3D.new()
	chairs.multimesh = MultiMesh.new()
	chairs.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	chairs.multimesh.mesh = chair_mesh
	chairs.multimesh.instance_count = 120
	var index := 0
	for side in [-1, 1]:
		for row in 5:
			for i in 12:
				chairs.multimesh.set_instance_transform(index, Transform3D(Basis(Vector3.UP, PI if side < 0 else 0), Vector3(-9.0 + i * 1.65, row * 0.35 - 0.15, side * (9.3 + row * 1.2))))
				index += 1
	chairs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(chairs)
	# Simple audience silhouettes add life without separate rigged characters.
	audience = MultiMeshInstance3D.new()
	audience.multimesh = MultiMesh.new()
	audience.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	audience.multimesh.use_colors = true
	audience.multimesh.mesh = RushModelFactory.bake([
		RushModelFactory.piece("sphere", Vector3(0.4, 0.55, 0.3), Vector3(0, 0.3, 0), Color("697586")),
		RushModelFactory.piece("sphere", Vector3(0.26, 0.27, 0.26), Vector3(0, 0.72, 0), Color("aa9483"))])
	audience.multimesh.instance_count = 80
	for i in 80:
		var side := -1 if i < 40 else 1
		var row := (i % 40) / 10
		var at := Vector3(-8.3 + (i % 10) * 1.8, row * 0.35, side * (9.3 + row * 1.2))
		audience.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, at))
		audience.multimesh.set_instance_color(i, Color.from_hsv(float(i % 7) / 7, 0.28, 0.7))
	audience.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(audience)

func set_stage(index: int) -> void:
	var tint: Color = RushBalance.STAGES[index].tint
	for accent in accents: accent.material_override.albedo_color = tint
	canvas.material_override.albedo_color = [Color("7c897f"), Color("747d99"), Color("9a8b6e")][index]

func set_quality(low: bool) -> void:
	key_light.shadow_enabled = not low
	audience.visible = not low

func showroom(enabled: bool) -> void:
	for child in get_children():
		if child is GeometryInstance3D: child.visible = not enabled
	if not enabled: set_quality(MobileCore.save.data.settings.get("low_quality", false))
