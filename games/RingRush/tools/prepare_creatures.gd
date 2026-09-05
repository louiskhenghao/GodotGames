extends SceneTree
const SOURCES:={"rattle":"Skeleton_Minion","shade":"Skeleton_Rogue","hex":"Skeleton_Mage"}
const CLIPS:={"Idle":"Unarmed_Idle","Jog_Fwd":"Running_A","Punch_Jab":"Unarmed_Melee_Attack_Punch_A","Punch_Cross":"Unarmed_Melee_Attack_Punch_B","Hit_Chest":"Hit_A","Death01":"Death_A","Jump_Land":"Jump_Land"}
func _initialize():call_deferred("run")
func run():
 for id in SOURCES:
  var scene:Node3D=load("res://assets/fighters/kaykit/"+SOURCES[id]+".glb").instantiate()
  root.add_child(scene)
  var player:AnimationPlayer=scene.find_child("AnimationPlayer",true,false)
  var library:=AnimationLibrary.new()
  for clip in CLIPS:
   var animation:Animation=player.get_animation(CLIPS[clip]).duplicate(true)
   animation.loop_mode=Animation.LOOP_LINEAR if clip in ["Idle","Jog_Fwd"] else Animation.LOOP_NONE
   library.add_animation(clip,animation)
  for name in player.get_animation_library_list():player.remove_animation_library(name)
  player.add_animation_library("",library)
  player.play("Idle");player.advance(0)
  var mesh_count:=0;var triangles:=0
  for mesh:MeshInstance3D in scene.find_children("*","MeshInstance3D",true,false):
   mesh_count+=1
   for surface in mesh.mesh.get_surface_count():triangles+=mesh.mesh.surface_get_array_index_len(surface)/3
  var packed:=PackedScene.new();packed.pack(scene)
  print(id," meshes ",mesh_count," triangles ",triangles," saved ",ResourceSaver.save(packed,"res://assets/fighters/kaykit/"+id+".scn",ResourceSaver.FLAG_COMPRESS))
  scene.queue_free();await process_frame
 quit()
