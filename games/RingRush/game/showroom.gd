class_name RushShowroom
extends Node3D
## Six authored, cached environments. Changing a fighter changes place, not only tint.
var scenes:Dictionary={}
var current_fighter:=""
func select_fighter(id:String) -> void:
 id=RushRoster.character(id).id
 if not scenes.has(id):scenes[id]=_build(id)
 for key in scenes:scenes[key].visible=key==id
 current_fighter=id
func piece(parts:Array,shape:String,size:Vector3,at:Vector3,color:String) -> void:
 parts.append(RushModelFactory.piece(shape,size,at,Color(color)))
func _build(id:String) -> Node3D:
 var scene:=Node3D.new();scene.name=id;add_child(scene)
 var parts:Array=[]
 var floor_color:String={"atlas":"172b34","zephyr":"1c3249","titan":"302a29","volt":"122d40","raven":"261e31","sol":"353b34","aegis":"302b35","ion":"17333c","onyx":"24253e"}[id]
 piece(parts,"box",Vector3(90,.2,90),Vector3(0,-.5,0),floor_color)
 if id=="atlas":
  piece(parts,"box",Vector3(18,8,.3),Vector3(0,3,-4.5),"243947")
  for i in 14:piece(parts,"box",Vector3(18,.024,.03),Vector3(0,.3+i*.43,-4.33),"304a57")
  for x in [-3.8,3.8]:
   piece(parts,"box",Vector3(.06,2,.06),Vector3(x,4,-2.6),"90a5a8")
   piece(parts,"cylinder",Vector3(.8,2.2,.8),Vector3(x,1.8,-2.6),"ad6652")
   piece(parts,"box",Vector3(.65,.3,.05),Vector3(x,2.3,-2.16),"d1b382")
  for x in [-6.0,5.0]:
   for i in 3:piece(parts,"box",Vector3(.8,2.5,.65),Vector3(x+i*.85,1,-4),"405660")
 elif id=="zephyr":
  for i in 11:
   var at:=Vector3(-12+i*2.6,1+i%4*.5,-8-i%2*3)
   piece(parts,"box",Vector3(2,4+i%4,2),at,"314e70" if i%2 else "253e59")
   for j in 3:piece(parts,"box",Vector3(1.4,.16,.05),at+Vector3(0,j*.75,1.03),"9ab8ce")
  for x in [-6.0,6.0]:
   piece(parts,"box",Vector3(.18,3,.18),Vector3(x,1.1,-3.8),"8aabbd")
   piece(parts,"box",Vector3(2,.7,1.6),Vector3(x,.1,-2),"3d5869")
  for y in [.4,1.0]:piece(parts,"box",Vector3(13,.08,.08),Vector3(0,y,-4),"7597b0")
 elif id=="titan":
  piece(parts,"box",Vector3(18,8,.3),Vector3(0,3,-4.6),"392c2b")
  for x in [-6.0,-3.8,3.8,6.0]:
   piece(parts,"box",Vector3(.45,7,.45),Vector3(x,2.8,-3.8),"70625a")
   piece(parts,"box",Vector3(1.4,2.5,.2),Vector3(x,2,-4.3),"c65e31")
   for y in range(6):piece(parts,"box",Vector3(1.5,.13,.12),Vector3(x,1+y*.4,-4.12),"312e30")
  for x in [-4.5,4.5]:
   piece(parts,"cylinder",Vector3(1.3,1.7,1.3),Vector3(x,.4,-1.6),"776148")
   piece(parts,"box",Vector3(1.4,.2,1.4),Vector3(x,.9,-1.6),"cca66a")
 elif id=="volt":
  piece(parts,"box",Vector3(18,8,.3),Vector3(0,3,-4.5),"112b42")
  for x in [-6,-4,4,6]:
   piece(parts,"box",Vector3(1.3,4,.35),Vector3(x,2,-4.1),"293d65")
   for y in range(5):piece(parts,"box",Vector3(.85,.3,.05),Vector3(x,.7+y*.6,-3.89),"5597bb" if y%2 else "796bba")
   piece(parts,"box",Vector3(.08,5,.06),Vector3(x+.78,2,-3.9),"64e2e2")
  for x in [-3.5,3.5]:
   piece(parts,"box",Vector3(1.25,.85,1.1),Vector3(x,.15,-1.5),"284c68")
   piece(parts,"sphere",Vector3(.55,.8,.55),Vector3(x,.9,-1.5),"80dce2")
 elif id=="raven":
  piece(parts,"box",Vector3(18,8,.3),Vector3(0,3,-4.6),"322c40")
  for row in 12:
   for col in 12:
    piece(parts,"box",Vector3(1.35,.4,.06),Vector3(-8+col*1.45+(row%2)*.7,.2+row*.48,-4.4),"4a3a4f" if (row+col)%3 else "594350")
  for x in [-5.5,5.5]:
   piece(parts,"box",Vector3(.13,6,.13),Vector3(x,2.4,-3.5),"656379")
   piece(parts,"box",Vector3(1.8,.8,1.1),Vector3(x,.0,-2),"333c49")
   piece(parts,"box",Vector3(1.9,.12,1.2),Vector3(x,.5,-2),"76878c")
  piece(parts,"box",Vector3(3.8,.1,.06),Vector3(-3.5,3.5,-4.2),"e47a9e")
 elif id in ["aegis","ion","onyx"]:
  var accent:String={"aegis":"d69463","ion":"66dbaa","onyx":"b394e7"}[id]
  piece(parts,"box",Vector3(18,8,.3),Vector3(0,3,-4.6),"243044")
  for x in [-6.0,-3.8,3.8,6.0]:
   piece(parts,"box",Vector3(.4,6,.5),Vector3(x,2,-4),"55677b")
   piece(parts,"box",Vector3(.08,4,.06),Vector3(x+.3,2,-3.7),accent)
   piece(parts,"box",Vector3(1.7,2.4,.3),Vector3(x,1.8,-4.2),"172337")
  for x in [-3.8,3.8]:
   if id=="aegis":
    for y in 3:piece(parts,"box",Vector3(1.4,.5,1),Vector3(x,y*.65,-1.8),"6c6962")
   elif id=="ion":
    piece(parts,"cylinder",Vector3(.7,3,.7),Vector3(x,1.0,-2),"436576")
    for y in 5:piece(parts,"cylinder",Vector3(1.1,.10,1.1),Vector3(x,.4+y*.45,-2),accent)
   else:
    piece(parts,"sphere",Vector3(1.4,1.4,1.4),Vector3(x,1.4,-2),accent)
    piece(parts,"cylinder",Vector3(1.8,.6,1.8),Vector3(x,.2,-2),"39455f")
 else:
  piece(parts,"box",Vector3(18,7,.3),Vector3(0,2.8,-4.6),"637069")
  for x in [-6,-3,3,6]:
   piece(parts,"box",Vector3(.35,6,.4),Vector3(x,2.4,-4.1),"8e4940")
   piece(parts,"box",Vector3(2.3,3.5,.1),Vector3(x,1.8,-4.35),"a9ae90")
   for j in range(4):piece(parts,"box",Vector3(2.4,.06,.12),Vector3(x,.5+j*.85,-4.23),"6e6450")
  piece(parts,"box",Vector3(16,.4,.7),Vector3(0,4.8,-4),"853f38")
  for x in [-4.6,4.6]:
   piece(parts,"cylinder",Vector3(.15,2.1,.15),Vector3(x,.4,-1.7),"69594a")
   for i in range(3):piece(parts,"sphere",Vector3(1.6,.9,1.2),Vector3(x+(i-1)*.45,1.4+i*.4,-1.7),"8a9b73")
 var mesh:=MeshInstance3D.new();mesh.mesh=RushModelFactory.bake(parts,12);scene.add_child(mesh)
 var sign:=Label3D.new();sign.font=load("res://assets/fonts/BarlowCondensed-Bold.ttf")
 sign.text={"atlas":"BOXING CLUB","zephyr":"SKYLINE / ROOFTOP","titan":"THE POWERHOUSE","volt":"VOLT / LAB","raven":"NIGHT DISTRICT","sol":"SUNRISE DOJO","aegis":"SENTINEL / HANGAR","ion":"ARC / LABORATORY","onyx":"NOVA / REACTOR"}[id]
 sign.font_size=80;sign.pixel_size=.0045;sign.outline_size=0
 sign.position=Vector3(-2.4,4.1,-4.1);sign.modulate=RushRoster.character(id).color.darkened(.45)
 scene.add_child(sign)
 return scene
