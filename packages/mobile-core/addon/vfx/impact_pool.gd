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
var detail:=1
var spectacle:CoreSpectaclePool
var projectile_mesh:MultiMeshInstance3D
var projectile_lives:=PackedFloat32Array()
var projectile_cursor:=0
var cracks: MultiMeshInstance3D
var crack_life := 0.0
var instanced: MultiMeshInstance3D
var strokes:Array[Dictionary]=[]
var stroke_cursor:=0

func _ready() -> void:
	spectacle=CoreSpectaclePool.new()
	add_child(spectacle)
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
	projectile_mesh=MultiMeshInstance3D.new()
	projectile_mesh.multimesh=MultiMesh.new()
	projectile_mesh.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	projectile_mesh.multimesh.use_colors=true
	var projectile_shape:=SphereMesh.new();projectile_shape.radius=.5;projectile_shape.height=1
	projectile_shape.radial_segments=8;projectile_shape.rings=4
	projectile_shape.material=material
	projectile_mesh.multimesh.mesh=projectile_shape
	projectile_mesh.multimesh.instance_count=128
	projectile_mesh.multimesh.custom_aabb=AABB(Vector3(-40,-8,-40),Vector3(80,32,80))
	projectile_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(projectile_mesh)
	projectile_lives.resize(128)
	for i in 128:projectile_mesh.multimesh.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO))
	instanced.multimesh.mesh = mesh
	instanced.multimesh.instance_count = capacity
	instanced.multimesh.custom_aabb = AABB(Vector3(-40, -8, -40), Vector3(80, 32, 80))
	instanced.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instanced)
	cracks = MultiMeshInstance3D.new()
	cracks.multimesh = MultiMesh.new()
	cracks.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	cracks.multimesh.use_colors = true
	var crack_mesh := BoxMesh.new()
	crack_mesh.size = Vector3.ONE
	crack_mesh.material = material
	cracks.multimesh.mesh = crack_mesh
	cracks.multimesh.instance_count = 96
	cracks.multimesh.custom_aabb = instanced.multimesh.custom_aabb
	cracks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cracks.visible = false
	add_child(cracks)
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
	var stroke_mesh:=BoxMesh.new()
	stroke_mesh.size=Vector3.ONE
	for i in 48:
		var node:=MeshInstance3D.new()
		node.mesh=stroke_mesh
		var m:=StandardMaterial3D.new()
		m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		node.material_override=m
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visible=false
		add_child(node)
		strokes.append({"node":node,"life":0.0})
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
	spectacle.clear()
	for i in 128:
		projectile_lives[i]=0
		projectile_mesh.multimesh.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO))
	crack_life = 0
	cracks.visible = false
	for i in capacity:
		particles[i].life = 0
		_hide(i)
	for p in rings:
		p.life = 0
		p.node.visible = false
	for p in strokes:
		p.life=0
		p.node.visible=false
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

func ring(origin: Vector3, color: Color, radius: float, duration: float = 0.45, essential:bool=false) -> void:
	if not enabled and not essential: return
	var p := rings[ring_cursor]
	ring_cursor = (ring_cursor + 1) % rings.size()
	p.node.rotation = Vector3.ZERO
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
	for i in 128:
		if projectile_lives[i]<=0:continue
		projectile_lives[i]-=delta
		if projectile_lives[i]<=0:projectile_mesh.multimesh.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO))
	crack_life = maxf(0,crack_life-delta)
	cracks.visible = crack_life > 0
	for p in strokes:
		p.life=maxf(0,p.life-delta)
		p.node.visible=p.life>0
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

func quake(origin: Vector3, color: Color, radius: float = 4.5) -> void:
	_fx().impact(origin,color,radius)
	crack_life = 1.4
	for ray in 8:
		var angle:float=ray*TAU/8+randf_range(-.15,.15)
		var forward:=Vector3(cos(angle),0,sin(angle))
		var side:=Vector3(-forward.z,0,forward.x)
		var previous:=origin+Vector3.UP*.09
		var branch:=previous
		var distance:float=radius*randf_range(.80,1.07)
		for segment in 4:
			var next:Vector3=origin+forward*(segment+1)*distance/4+side*randf_range(-.25,.25)+Vector3.UP*.09
			_crack(ray*4+segment,previous,next,color,.2-segment*.043)
			if segment==1:branch=next
			previous=next
		var direction:=forward.rotated(Vector3.UP,randf_range(.55,.9)*(1 if ray%2 else -1))
		for segment in 2:
			var next:Vector3=branch+direction*radius*.19+side*randf_range(-.13,.13)
			_crack(32+ray*2+segment,branch,next,color,.095-segment*.035)
			branch=next
	ring(origin,color,radius,.65,true)
	ring(origin,Color("fff3b4"),radius*.7,.45,true)
	burst(origin+Vector3.UP*.15,Color("c19b70"),48,1.6)

func _crack(index:int,from:Vector3,to:Vector3,color:Color,width:float) -> void:
	var direction:=to-from
	var basis:=Basis(Vector3.UP,atan2(-direction.x,-direction.z))
	var center:Vector3=(from+to)*.5
	cracks.multimesh.set_instance_transform(index,Transform3D(basis.scaled_local(Vector3(width,.01,direction.length()+.035)),center))
	cracks.multimesh.set_instance_color(index,Color("483c39"))
	cracks.multimesh.set_instance_transform(48+index,Transform3D(basis.scaled_local(Vector3(width*.26,.014,direction.length()+.03)),center+Vector3.UP*.012))
	cracks.multimesh.set_instance_color(48+index,color.lerp(Color("fff0a2"),.25))

func cyclone(origin: Vector3, color: Color, radius: float = 2.8) -> void:
	_fx().vortex(origin,color,radius)
	for height in [.2,.8,1.4]:
		var index := ring_cursor
		ring(origin+Vector3.UP*height,color,radius,.36,true)
		rings[index].node.rotation.z = .10
	if not enabled:return
	for i in 16:
		var angle := i*TAU/16
		var p := particles[cursor]
		p.position = origin+Vector3(cos(angle)*radius,.8,sin(angle)*radius)
		p.velocity = Vector3(-sin(angle)*4,2,cos(angle)*4)
		p.life = .28
		instanced.multimesh.set_instance_color(cursor,color)
		cursor = (cursor+1)%capacity

func stroke(from:Vector3,to:Vector3,color:Color,width:float=.10,duration:float=.22) -> void:
	var direction:=to-from
	if direction.length_squared()<.00001:return
	var p:=strokes[stroke_cursor]
	stroke_cursor=(stroke_cursor+1)%strokes.size()
	p.node.transform=Transform3D(Basis.looking_at(direction,Vector3.RIGHT if absf(direction.normalized().y)>.95 else Vector3.UP).scaled_local(Vector3(width,width,direction.length())),(from+to)*.5)
	p.node.material_override.albedo_color=color
	p.node.visible=true
	p.life=duration

func lightning(from:Vector3,to:Vector3,color:Color) -> void:
	_fx().flash(to,color,.85)
	var previous:=from
	for i in 6:
		var next:=from.lerp(to,(i+1)/6.0)
		if i<5:next+=Vector3(sin(i*2.5)*.22,cos(i*2.1)*.12,0)
		stroke(previous,next,color,.17,.28)
		stroke(previous,next,Color("edfcff"),.045,.32)
		previous=next

func strike(origin:Vector3,direction:Vector3,color:Color) -> void:
	var side:=Vector3(-direction.z,0,direction.x)
	for i in 3:
		var start:=origin+Vector3.UP*(.8+i*.18)+side*(i-1)*.23
		stroke(start,start+direction*(1.6+i*.16),color,.10,.16)

func wall_impact(at:Vector3,color:Color) -> void:
	ring(Vector3(at.x,0,at.z),color,1.35,.4,true)
	for i in 6:
		var delta:=Vector3(cos(i*TAU/6),sin(i*TAU/6),.15)*.9
		stroke(at,at+delta,color,.10,.3)
	burst(at,color,18,1.1)

func _fx() -> CoreSpectaclePool:
	spectacle.enabled=enabled
	spectacle.detail=detail
	return spectacle

func hit_flash(at:Vector3,color:Color) -> void:
	_fx().flash(at,color,.55)

func muzzle(at:Vector3,color:Color,size:float=.6) -> void:
	_fx().flash(at,color,size)

func explosion(at:Vector3,color:Color,radius:float) -> void:
	_fx().impact(Vector3(at.x,0,at.z),color,radius,.45)
	ring(Vector3(at.x,0,at.z),color,radius,.38,true)

func projectile(at:Vector3,direction:Vector3,color:Color,kind:String,radius:float,trail:bool=true) -> void:
	# Always visible, including with decorative effects disabled. Gameplay owns hit radius.
	var length:=.65 if kind=="bullet" else .5
	var basis:=Basis.looking_at(direction,Vector3.RIGHT if absf(direction.y)>.95 else Vector3.UP).scaled_local(Vector3(radius*1.1,radius*1.1,length))
	projectile_mesh.multimesh.set_instance_transform(projectile_cursor,Transform3D(basis,at-direction*length*.35))
	projectile_mesh.multimesh.set_instance_color(projectile_cursor,color)
	projectile_lives[projectile_cursor]=.055
	projectile_cursor=(projectile_cursor+1)%128
	if not trail:return
	_fx().flash(at,color,radius*1.8)
	if kind in ["missile","orb"]:_fx().smoke(at-direction*.3,Color("a99a9b"),.18)

func flame_jet(at:Vector3,direction:Vector3,length:float,color:Color) -> void:
	_fx().flame(at,direction,length,color)
	for side in [-1,0,1]:
		stroke(at,at+direction*length+Vector3(direction.z,0,-direction.x)*side*.32,color,.065,.16)
