extends SceneTree
func _initialize():call_deferred("run")
func run():
 for id in ["aegis","ion","onyx"]:
  var scene=load("res://assets/fighters/mechs/"+id+".glb").instantiate();root.add_child(scene)
  print(id)
  var sk:Skeleton3D=scene.find_child("Skeleton3D",true,false)
  print("bones ",PackedStringArray(range(sk.get_bone_count()).map(func(i):return sk.get_bone_name(i))))
  print("clips ",scene.find_child("AnimationPlayer",true,false).get_animation_list())
  for mesh:MeshInstance3D in scene.find_children("*","MeshInstance3D",true,false):print(mesh.name," ",mesh.get_aabb()," global ",mesh.global_transform)
  scene.free()
 quit()
