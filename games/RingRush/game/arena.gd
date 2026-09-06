class_name RushArena
extends Node3D
var venues: Array[Node3D] = []
var ring_nodes: Array[Node3D] = []
var vents: Array[MeshInstance3D] = []
var current_stage := 0
var in_showroom := false
var key_light: DirectionalLight3D
var canvas: MeshInstance3D
var accents: Array[MeshInstance3D] = []
var audience: MultiMeshInstance3D
var showcase:RushShowroom

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

	for child in get_children():
		if child is GeometryInstance3D:
			ring_nodes.append(child)
			child.position*=Vector3(RushArenaLayout.SCALE,1,RushArenaLayout.SCALE)
			child.scale*=Vector3(RushArenaLayout.SCALE,1,RushArenaLayout.SCALE)
	venues.append(self)
	_build_venues()
	_build_rift()
	for stage_id in range(6,RushBalance.STAGES.size()):
		var venue:=RushFrontierVenues.build(self,stage_id)
		venues.append(venue)
	_build_showcase()
	showcase.visible=false

func set_stage(index: int) -> void:
	current_stage = clampi(index,0,venues.size()-1)
	for node in ring_nodes: node.visible = current_stage == 0 and not in_showroom
	for i in range(1,venues.size()): venues[i].visible = i == current_stage and not in_showroom
	key_light.light_color = [Color("ffe7c0"),Color("cbbfff"),Color("b9daff"),Color("ffcc9e"),Color("ffe4b6"),Color("cec5ff"),Color("fff4cf"),Color("b8e6df"),Color("bddcff")][current_stage]
	set_quality(MobileCore.save.data.settings.get("low_quality",false))

func set_quality(low: bool) -> void:
	key_light.shadow_enabled = not low
	audience.visible = not low and current_stage == 0 and not in_showroom

func showroom(enabled: bool) -> void:
	in_showroom = enabled
	set_stage(current_stage)
	if enabled:key_light.light_color=Color("ffe7d1")

func _batch(parent: Node3D, parts: Array, detail:int=8) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = RushModelFactory.bake(parts, detail)
	parent.add_child(mesh)

func _sign(parent: Node3D, text: String, at: Vector3, tint: Color, flat: bool = false) -> void:
	var sign := Label3D.new()
	sign.text = text
	sign.font = load("res://assets/fonts/BarlowCondensed-Bold.ttf")
	sign.font_size = 80
	sign.pixel_size = .014
	sign.outline_size = 0
	sign.modulate = tint
	sign.position = at
	if flat: sign.rotation_degrees.x = -90
	parent.add_child(sign)

func _build_venues() -> void:
	for index in range(1,5):
		var venue := Node3D.new()
		add_child(venue)
		venues.append(venue)
		var parts: Array = []
		var ground: Color = [Color("243342"),Color("455569"),Color("403830"),Color("8f9c8d")][index-1]
		_floor(venue,index,ground)
		# Venue geometry and shared collision boundaries use the same horizontal scale.
		if index == 1:
			for side in [-1,1]:
				parts.append(RushModelFactory.piece("box",Vector3(.8,.15,16),Vector3(side*7.4,.02,0),Color("6e7780")))
				for i in 4:
					var x: float = side*(8.7+float(i%2)*.4)
					var z := -6.0+i*4.2
					parts.append(RushModelFactory.piece("box",Vector3(2.3,5+i%2 if side<0 else 1.25,3.6),Vector3(x,1.9 if side<0 else .4,z),Color("253443") if i%2 else Color("394452")))
					for floor in (3 if side<0 else 1):
						parts.append(RushModelFactory.piece("box",Vector3(.04,.7,1.6),Vector3(x-side*1.17,1+floor*1.15,z),Color("dbac77") if floor%2 else Color("798aaf")))
				for i in 3:
					parts.append(RushModelFactory.piece("box",Vector3(.16,3,.16),Vector3(side*6.9,1.5,-5+i*5),Color("6d7689")))
					parts.append(RushModelFactory.piece("box",Vector3(.6,.1,.35),Vector3(side*6.7,3,-5+i*5),Color("a9eddf")))
			for i in 7: parts.append(RushModelFactory.piece("box",Vector3(.12,.02,1.15),Vector3(0,.01,-6+i*2),Color("beb68d")))
			for x in [-3.5,3.5]:
				parts.append(RushModelFactory.piece("box",Vector3(1.6,.65,3.1),Vector3(x,.3,-8),Color("384961")))
				parts.append(RushModelFactory.piece("box",Vector3(1.35,.55,1.5),Vector3(x,.85,-8),Color("61717f")))
			_sign(venue,"NEON / 24",Vector3(-7,3.3,-5.9),Color("ff87c5"))
			_sign(venue,"NO WAY OUT",Vector3(0,.04,4.8),Color("9e7180"),true)
		elif index == 2:
			var boundary:=RushArenaLayout.base_polygon(index)
			for i in boundary.size():
				var a:=boundary[i]
				var b:=boundary[(i+1)%boundary.size()]
				var d:=b-a
				var rail:=RushModelFactory.piece("box",Vector3(.16,.28,d.length()),Vector3((a.x+b.x)*.5,.14,(a.y+b.y)*.5),Color("8a9bac"))
				rail.rotation=Vector3(0,atan2(-d.x,-d.y),0)
				parts.append(rail)
			for i in 18:
				var angle := i*TAU/18
				var at := Vector3(cos(angle)*16, -3, sin(angle)*16)
				parts.append(RushModelFactory.piece("box",Vector3(2.5,5+i%5,2.5),at,Color("263d59")))
			for x in [-3.0,3.0]:
				parts.append(RushModelFactory.piece("box",Vector3(.15,.02,7),Vector3(x,.02,0),Color("d4bf87")))
			parts.append(RushModelFactory.piece("box",Vector3(6,.02,.15),Vector3(0,.02,3.5),Color("d4bf87")))
			parts.append(RushModelFactory.piece("box",Vector3(6,.02,.15),Vector3(0,.02,-3.5),Color("d4bf87")))
			_sign(venue,"H",Vector3(0,.04,0),Color("c9c6a8"),true)
		elif index == 3:
			for x in [-8.0,8.0]:
				for z in [-6.0,-2.0,2.0,6.0]:
					parts.append(RushModelFactory.piece("box",Vector3(1,5,1),Vector3(x,2.0,z),Color("55545a")))
					parts.append(RushModelFactory.piece("box",Vector3(1.5,.4,2.8),Vector3(x,.1,z),Color("a96f36")))
					parts.append(RushModelFactory.piece("box",Vector3(.08,2.5,1.6),Vector3(x-signf(x)*.54,1.6,z),Color("e57c3c")))
			for i in 8:
				parts.append(RushModelFactory.piece("box",Vector3(14,.018,.045),Vector3(0,.02,-6+i*1.7),Color("55504c")))
			_sign(venue,"CAUTION / PRESSURE",Vector3(0,.035,-4.8),Color("e0a65c"),true)
		else:
			for i in 9:
				for j in 9:
					var tile:=Vector2(-6+i*1.5,-6+j*1.5)
					if (RushArenaLayout.constrain(Vector3(tile.x,0,tile.y)*RushArenaLayout.SCALE,index,RushArenaLayout.SCALE)/RushArenaLayout.SCALE).distance_to(Vector3(tile.x,0,tile.y))>.1:continue
					parts.append(RushModelFactory.piece("box",Vector3(1.45,.025,1.45),Vector3(-6+i*1.5,.01,-6+j*1.5),Color("a9b3a1") if (i+j)%2 else Color("9ea996")))
			for x in [-7.5,7.5]:
				for z in [-7.5,7.5]:
					parts.append(RushModelFactory.piece("box",Vector3(.55,3.4,.55),Vector3(x,1.5,z),Color("933d34")))
					parts.append(RushModelFactory.piece("box",Vector3(2,.3,2),Vector3(x,3.3,z),Color("384b4d")))
					parts.append(RushModelFactory.piece("sphere",Vector3(.7,.9,.7),Vector3(x,2.4,z),Color("e8bc65")))
			parts.append(RushModelFactory.piece("box",Vector3(15,.5,1),Vector3(0,3.7,-7.5),Color("923f34")))
			for x in [-11.0,11.0]:
				parts.append(RushModelFactory.piece("box",Vector3(.55,5,.55),Vector3(x,1.5,-3),Color("4a5143")))
				parts.append(RushModelFactory.piece("sphere",Vector3(5,3,5),Vector3(x,4,-3),Color("b991a7")))
			_sign(venue,"DAWN / FINAL ASCENT",Vector3(0,.045,4.5),Color("5f7464"),true)
		var stretch:=Vector3(.75,1,1.36) if index==1 else (Vector3(1.2,1,.72) if index==3 else Vector3.ONE)
		for part in parts:
			part.at*=stretch
			part.size*=stretch
		_batch(venue,parts)
		_populate(venue,index)
		_build_surroundings(venue,index)
		venue.scale=Vector3(RushArenaLayout.SCALE,1,RushArenaLayout.SCALE)
		venue.visible = false
	# Two reusable steam vent telegraphs for the foundry; game owns their damage timing.
	for at in [Vector3(-3,0,1.8),Vector3(3,0,-1.8)]:
		var marker := MeshInstance3D.new()
		var circle := TorusMesh.new()
		circle.inner_radius=1.05
		circle.outer_radius=1.18
		circle.rings=32
		circle.ring_segments=4
		marker.mesh=circle
		marker.position=at+Vector3.UP*.08
		marker.scale.y=.08
		marker.material_override=RushBoxer.material(Color("e4a05e"))
		marker.material_override.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		venues[3].add_child(marker)
		vents.append(marker)

func update_hazards(time: float) -> bool:
	var phase := fmod(time,8.0)
	for vent in vents:
		vent.material_override.albedo_color = Color("ff5f47") if phase > 6 else (Color("ffbc5e") if phase > 4.5 else Color("65554b"))
	return current_stage == 3 and phase > 6

func _floor(parent:Node3D,index:int,color:Color) -> void:
	var polygon:=RushArenaLayout.base_polygon(index)
	var triangles:=Geometry2D.triangulate_polygon(polygon)
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_color(color)
	for i in range(0,triangles.size(),3):
		for j in [0,1,2]:
			var point:=polygon[triangles[i+j]]
			surface.set_normal(Vector3.UP)
			surface.add_vertex(Vector3(point.x,-.035,point.y))
	for i in polygon.size():
		var a:=polygon[i]
		var b:=polygon[(i+1)%polygon.size()]
		var normal:=Vector3((b-a).y,0,-(b-a).x).normalized()
		for v in [Vector3(a.x,-.035,a.y),Vector3(a.x,-.38,a.y),Vector3(b.x,-.38,b.y),Vector3(a.x,-.035,a.y),Vector3(b.x,-.38,b.y),Vector3(b.x,-.035,b.y)]:
			surface.set_normal(normal)
			surface.add_vertex(v)
	var mesh:=MeshInstance3D.new()
	mesh.mesh=surface.commit()
	mesh.material_override=RushBoxer.material(Color.WHITE)
	mesh.material_override.vertex_color_use_as_albedo=true
	parent.add_child(mesh)

func _populate(parent:Node3D,index:int) -> void:
	var parts:Array=[]
	for obstacle in RushArenaLayout.base_blockers(index):
		var center:=Vector3(obstacle.x,0,obstacle.y)
		if index==1:
			parts.append(RushModelFactory.piece("box",Vector3(1.15,.8,1.15),center+Vector3.UP*.4,Color("405c64")))
			parts.append(RushModelFactory.piece("box",Vector3(1.25,.12,1.25),center+Vector3.UP*.86,Color("8b9b89")))
		elif index==2:
			parts.append(RushModelFactory.piece("box",Vector3(1.3,.85,1.3),center+Vector3.UP*.43,Color("7893a3")))
			for i in 6:parts.append(RushModelFactory.piece("box",Vector3(1.35,.035,.06),center+Vector3(0,.89,-.45+i*.18),Color("263f50")))
		elif index==3:
			parts.append(RushModelFactory.piece("sphere",Vector3(1.6,1.1,1.6),center+Vector3.UP*.53,Color("775443")))
			parts.append(RushModelFactory.piece("box",Vector3(1.5,.16,1.5),center+Vector3.UP*.5,Color("b99662")))
		else:
			parts.append(RushModelFactory.piece("box",Vector3(1.1,.5,1.1),center+Vector3.UP*.25,Color("6e867e")))
			parts.append(RushModelFactory.piece("sphere",Vector3(.9,.35,.9),center+Vector3.UP*.63,Color("b9b197")))
	if index in [1,2,4]:
		for i in 8:
			var at:=RushArenaLayout.spawn_point(index,i*TAU/8)/RushArenaLayout.SCALE
			at+=at.normalized()*2.3
			parts.append(RushModelFactory.piece("box",Vector3(.25,2.1,.25),at+Vector3.UP,Color("554f43")))
			for j in 4:
				var offset:=Vector3(cos(j*TAU/4)*.45,2+j%2*.3,sin(j*TAU/4)*.45)
				parts.append(RushModelFactory.piece("sphere",Vector3(1.35,1.1,1.35),at+offset,Color("7e9a74") if index!=4 else Color("b5bca1")))
	_batch(parent,parts)
	# Static onlookers use shared poses through instancing, not extra animated actors.
	var library: RushCrowdLibrary=load("res://assets/fighters/crowd.res")
	var mesh:Mesh=library.clips.Idle[0].duplicate()
	var skin:=RushBoxer.material(Color.WHITE)
	skin.albedo_texture=load("res://assets/fighters/T_Superhero_Male_Dark.png")
	skin.vertex_color_use_as_albedo=true
	mesh.surface_set_material(0,skin)
	var cloth:=RushBoxer.material(Color("798a9d"))
	cloth.vertex_color_use_as_albedo=true
	mesh.surface_set_material(1,cloth)
	var crowd:=MultiMeshInstance3D.new()
	crowd.multimesh=MultiMesh.new()
	crowd.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	crowd.multimesh.use_colors=true
	crowd.multimesh.mesh=mesh
	crowd.multimesh.instance_count=18
	for i in 18:
		var angle:=i*TAU/18
		var at:=RushArenaLayout.spawn_point(index,angle)/RushArenaLayout.SCALE
		at+=at.normalized()*1.15
		crowd.multimesh.set_instance_transform(i,Transform3D(Basis(Vector3.UP,atan2(-at.x,-at.z)).scaled(Vector3.ONE*.88),at))
		crowd.multimesh.set_instance_color(i,Color.from_hsv(i*.13,.2,.85))
	crowd.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(crowd)

func _build_showcase() -> void:
	showcase=RushShowroom.new();add_child(showcase)
	showcase.select_fighter("atlas")

func _build_rift() -> void:
	var venue:=Node3D.new();venue.name="RiftNecropolis";add_child(venue);venues.append(venue)
	_floor(venue,5,Color("322d46"))
	var parts:Array=[]
	parts.append(RushModelFactory.piece("box",Vector3(90,.2,90),Vector3(0,-.6,0),Color("151824")))
	for i in 16:
		var a:=i*TAU/16
		var at:=Vector3(cos(a)*9.5,0,sin(a)*9.5)
		parts.append(RushModelFactory.piece("box",Vector3(.7,1.5,.4),at+Vector3.UP*.55,Color("65717d")))
		parts.append(RushModelFactory.piece("box",Vector3(1.0,.24,.46),at+Vector3.UP*.9,Color("8c94a3")))
		parts.append(RushModelFactory.piece("sphere",Vector3(.32,.42,.32),at+Vector3(0,1.7,0),Color("b8a0ec")))
	for obstacle in RushArenaLayout.base_blockers(5):
		var at:=Vector3(obstacle.x,0,obstacle.y)
		parts.append(RushModelFactory.piece("cylinder",Vector3(1.7,.65,1.7),at+Vector3.UP*.28,Color("555c72")))
		parts.append(RushModelFactory.piece("sphere",Vector3(.6,1.3,.6),at+Vector3.UP,Color("a28dd5")))
	for x in [-2.8,2.8]:parts.append(RushModelFactory.piece("box",Vector3(.8,4,.8),Vector3(x,1.8,-8),Color("5b6077")))
	parts.append(RushModelFactory.piece("box",Vector3(6.5,.7,1),Vector3(0,4,-8),Color("77718f")))
	_batch(venue,parts,12)
	for radius in [3.0,5.7,7.7]:
		var ring:=MeshInstance3D.new();var torus:=TorusMesh.new()
		torus.inner_radius=radius;torus.outer_radius=radius+.06;torus.rings=64;torus.ring_segments=4
		ring.mesh=torus;ring.position.y=.025;ring.scale.y=.1
		ring.material_override=RushBoxer.material(Color("a48ad9"));ring.material_override.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		venue.add_child(ring)
	_sign(venue,"THE RIFT",Vector3(0,2.7,-7.9),Color("dbc3fa"))
	venue.scale=Vector3(RushArenaLayout.SCALE,1,RushArenaLayout.SCALE);venue.visible=false

func _build_surroundings(parent:Node3D,index:int) -> void:
	var parts:Array=[]
	var ground_y:float=-8.5 if index==2 else -.58
	var tint:Color=[Color("243743"),Color("172e42"),Color("363d3e"),Color("56665b")][index-1]
	parts.append(RushModelFactory.piece("box",Vector3(90,.20,90),Vector3(0,ground_y,0),tint))
	if index==1:
		for side in [-1,1]:
			parts.append(RushModelFactory.piece("box",Vector3(3,.20,28),Vector3(side*7.2,-.28,0),Color("52616a")))
			for i in 6:
				parts.append(RushModelFactory.piece("box",Vector3(.14,.02,1.4),Vector3(side*4.95,-.22,-11+i*4.4),Color("8f988b")))
	elif index==2:
		for i in 18:
			var at:=Vector3(-24+i%6*8,-5,-20+i/6*14)
			if absf(at.x)<10 and absf(at.z)<10:continue
			parts.append(RushModelFactory.piece("box",Vector3(4,3+i%4,5),at,Color("2d4556")))
	elif index==3:
		for z in [-8.0,8.0]:
			parts.append(RushModelFactory.piece("box",Vector3(28,.12,1.5),Vector3(0,-.29,z),Color("5e5a4b")))
			for i in 10:parts.append(RushModelFactory.piece("box",Vector3(.25,.08,1.4),Vector3(-13+i*2.8,-.18,z),Color("9f874e")))
	else:
		for i in 16:
			var angle:=i*TAU/16
			var at:=Vector3(cos(angle)*21,-1,sin(angle)*21)
			parts.append(RushModelFactory.piece("sphere",Vector3(12,4+i%3,10),at,Color("49665c") if i%2 else Color("5c7361")))
	_batch(parent,parts)
