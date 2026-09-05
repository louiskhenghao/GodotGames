extends SceneTree
const CLIPS:={"Idle":"Idle","Jog_Fwd":"Run","Punch_Jab":"Shoot_Small","Punch_Cross":"Shoot_Big","Hit_Chest":"HitRecieve_1","Death01":"Death","Jump_Land":"Jump_Landing"}
func _initialize():call_deferred("run")
func run():
 for id in ["aegis","ion","onyx"]:
  var wrapper:=Node3D.new();wrapper.name="CombatMech";root.add_child(wrapper)
  var scene:Node3D=load("res://assets/fighters/mechs/"+id+".glb").instantiate();wrapper.add_child(scene);scene.owner=wrapper
  var player:AnimationPlayer=scene.find_child("AnimationPlayer",true,false)
  var library:=AnimationLibrary.new()
  for clip in CLIPS:
   var anim:Animation=player.get_animation("RobotArmature|"+CLIPS[clip]).duplicate(true)
   anim.loop_mode=Animation.LOOP_LINEAR if clip in ["Idle","Jog_Fwd"] else Animation.LOOP_NONE
   library.add_animation(clip,anim)
  for name in player.get_animation_library_list():player.remove_animation_library(name)
  player.add_animation_library("",library);player.play("Idle");player.advance(0)
  var bounds:=AABB();var first:=true;var triangles:=0
  for mesh:MeshInstance3D in scene.find_children("*","MeshInstance3D",true,false):
   var box: AABB=mesh.global_transform*mesh.get_aabb()
   bounds=box if first else bounds.merge(box);first=false
   for surface in mesh.mesh.get_surface_count():triangles+=mesh.mesh.surface_get_array_index_len(surface)/3
  var ratio:=1.85/bounds.size.y
  scene.scale*=ratio;scene.position.y=-bounds.position.y*ratio
  for target:MeshInstance3D in scene.find_children("*","MeshInstance3D",true,false):
   var original:Mesh=target.mesh;var metal:=ArrayMesh.new()
   for surface in original.get_surface_count():
    var a:=original.surface_get_arrays(surface)
    var kept:=PackedInt32Array();var indices:PackedInt32Array=a[Mesh.ARRAY_INDEX]
    for triangle in range(0,indices.size(),3):
     var weight:=0.0
     for vertex in 3:
      var index:int=indices[triangle+vertex]
      for slot in 4:
       if a[Mesh.ARRAY_BONES][index*4+slot] in [3,4]:weight+=a[Mesh.ARRAY_WEIGHTS][index*4+slot]
     if weight<1.5:kept.append_array(indices.slice(triangle,triangle+3))
    a[Mesh.ARRAY_INDEX]=kept
    for slot in range(Mesh.ARRAY_CUSTOM0,Mesh.ARRAY_CUSTOM3+1):a[slot]=null
    metal.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
    metal.surface_set_material(surface,original.surface_get_material(surface))
   target.mesh=metal
  var packed:=PackedScene.new();packed.pack(scene)
  print(id," triangles ",triangles," bounds ",bounds," scale ",ratio," saved ",ResourceSaver.save(packed,"res://assets/fighters/mechs/"+id+".scn",ResourceSaver.FLAG_COMPRESS))
  wrapper.free()
 quit()
