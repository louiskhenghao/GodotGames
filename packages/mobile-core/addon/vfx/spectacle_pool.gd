class_name CoreSpectaclePool
extends Node3D
## Four fixed instanced pools: angular debris, soft dust, additive light and ground waves.
## No per-impact nodes, dynamic lights, textures or screen-reading shaders.
var detail:=1
var enabled:=true
var groups:Dictionary={}
func _ready():
 var rock:=_rock_mesh()
 var stone:=StandardMaterial3D.new();stone.vertex_color_use_as_albedo=true;stone.roughness=.94
 _pool("rock",96,rock,stone)
 for entry in [["dust",64,"cloud"],["light",64,"flare"],["wave",12,"shockwave"]]:
  var quad:=QuadMesh.new();quad.size=Vector2.ONE*2
  var mat:=ShaderMaterial.new();mat.shader=load("res://addons/mobile_core/vfx/"+entry[2]+".gdshader")
  _pool(entry[0],entry[1],quad,mat)
func _pool(id:String,count:int,mesh:Mesh,material:Material):
 var node:=MultiMeshInstance3D.new();var multi:=MultiMesh.new()
 multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_colors=true;multi.use_custom_data=true
 multi.mesh=mesh;multi.instance_count=count
 multi.custom_aabb=AABB(Vector3(-45,-8,-45),Vector3(90,32,90))
 node.multimesh=multi;node.material_override=material
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)
 var slots:Array[Dictionary]=[]
 for i in count:
  slots.append({"life":0.0});multi.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO))
 groups[id]={"node":node,"slots":slots,"cursor":0}
func clear():
 for group in groups.values():
  for i in group.slots.size():
   group.slots[i].life=0
   group.node.multimesh.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO))
func emit_piece(id:String,at:Vector3,velocity:Vector3,color:Color,size:float,life:float,mode:float=0):
 if not enabled:return
 var group:Dictionary=groups[id];var index:int=group.cursor
 group.cursor=(index+1)%group.slots.size()
 var seed:=randf()
 group.slots[index]={"life":life,"duration":life,"at":at,"velocity":velocity,"size":size,"seed":seed,"mode":mode}
 group.node.multimesh.set_instance_color(index,color)
 _place(id,group,index,0)
func _place(id:String,group:Dictionary,index:int,progress:float):
 var p:Dictionary=group.slots[index]
 var size:float=p.size
 var basis:=Basis.IDENTITY
 if id=="rock":
  size*=minf(1,p.life*4)
  basis=Basis.from_euler(Vector3(p.seed*9,p.seed*4,p.seed*7)*(1+progress*4))
 elif id=="wave":basis=Basis(Vector3.RIGHT,-PI/2);size*=.45+progress*.65
 else:size*=1+progress*(1.7 if id=="dust" else .45)
 group.node.multimesh.set_instance_transform(index,Transform3D(basis.scaled(Vector3.ONE*size),p.at))
 group.node.multimesh.set_instance_custom_data(index,Color(progress,p.seed,p.mode,0))
func _process(delta:float):
 for id in groups:
  var group:Dictionary=groups[id]
  for i in group.slots.size():
   var p:Dictionary=group.slots[i]
   if p.life<=0:continue
   p.life=maxf(0,p.life-delta)
   if p.life<=0:
    group.node.multimesh.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO));continue
   if id=="rock":p.velocity.y-=delta*14
   p.at+=p.velocity*delta
   if id=="rock" and p.at.y<.08:p.at.y=.08;p.velocity*=.25;p.velocity.y=absf(p.velocity.y)
   _place(id,group,i,1-p.life/p.duration)
func impact(at:Vector3,color:Color,radius:float,power:float=1):
 if not enabled:return
 var count:=int((42 if detail>0 else 16)*power)
 for i in count:
  var angle:=i*TAU/count+randf_range(-.15,.15);var direction:=Vector3(cos(angle),0,sin(angle))
  var distance:=randf_range(.1,radius*.65)
  emit_piece("rock",at+direction*distance+Vector3.UP*.18,direction*randf_range(1.8,4.8)*power+Vector3.UP*randf_range(3.5,7.8),Color("90715c").lerp(Color("d2b491"),randf()),randf_range(.16,.52)*power,randf_range(1.0,1.55))
 var dust_count:=int((18 if detail>0 else 7)*power)
 for i in dust_count:
  var angle:=i*TAU/dust_count;var dir:=Vector3(cos(angle),0,sin(angle))
  emit_piece("dust",at+dir*radius*.5+Vector3.UP*.25,dir*2+Vector3.UP*.7,Color("d7b38b"),randf_range(.5,.9),1.05)
  if detail>0:emit_piece("light",at+dir*radius*.45+Vector3.UP*.25,dir*3+Vector3.UP*3,color,randf_range(.65,1.1),.65,2)
 emit_piece("wave",at+Vector3.UP*.11,Vector3.ZERO,color,radius*1.2,.7)
 emit_piece("light",at+Vector3.UP*.35,Vector3.UP*.15,Color("ffd765"),1.8*power,.32)
func flash(at:Vector3,color:Color,size:float=.65):
 emit_piece("light",at,Vector3.ZERO,color,size,.24)
func smoke(at:Vector3,color:Color,size:float=.4):
 emit_piece("dust",at,Vector3.UP*.4,color,size,.65)
func vortex(at:Vector3,color:Color,radius:float):
 emit_piece("wave",at+Vector3.UP*.18,Vector3.ZERO,color,radius,.45,1)
 var count:=6 if detail>0 else 3
 for i in count:
  var a:=i*TAU/count
  emit_piece("light",at+Vector3(cos(a)*radius,.8,sin(a)*radius),Vector3(-sin(a),.7,cos(a))*3,color,.55,.32)
func flame(at:Vector3,direction:Vector3,length:float,color:Color):
 var count:=10 if detail>0 else 5
 for i in count:
  var distance:float=float(i)/(count-1)*length
  var side:=Vector3(direction.z,0,-direction.x)*randf_range(-.25,.25)*(1+distance*.3)
  emit_piece("dust",at+direction*distance+side,direction*2+Vector3.UP*.3,color,.28+distance*.13,.30,1)
 if detail>0:smoke(at+direction*length,Color("766a75"),.45)
static func _rock_mesh() -> ArrayMesh:
 var t:float=(1.0+sqrt(5.0))/2.0
 var corners:=[Vector3(-1,t,0),Vector3(1,t,0),Vector3(-1,-t,0),Vector3(1,-t,0),Vector3(0,-1,t),Vector3(0,1,t),Vector3(0,-1,-t),Vector3(0,1,-t),Vector3(t,0,-1),Vector3(t,0,1),Vector3(-t,0,-1),Vector3(-t,0,1)]
 for i in corners.size():corners[i]=corners[i].normalized()*(.6+fmod(i*.137,.28))*Vector3(1.1,.8,1)
 var vertices:=PackedVector3Array();var normals:=PackedVector3Array()
 for face in [[0,11,5],[0,5,1],[0,1,7],[0,7,10],[0,10,11],[1,5,9],[5,11,4],[11,10,2],[10,7,6],[7,1,8],[3,9,4],[3,4,2],[3,2,6],[3,6,8],[3,8,9],[4,9,5],[2,4,11],[6,2,10],[8,6,7],[9,8,1]]:
  var n:Vector3=(corners[face[1]]-corners[face[0]]).cross(corners[face[2]]-corners[face[0]]).normalized()
  for index in face:vertices.append(corners[index]);normals.append(n)
 var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh
