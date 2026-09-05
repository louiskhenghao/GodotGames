extends SceneTree
func _initialize():call_deferred("run")
func run():
 for id in ["aegis","ion","onyx"]:
  var scene=load("res://assets/fighters/mechs/"+id+".scn").instantiate();root.add_child(scene)
  var mesh:MeshInstance3D=scene.find_children("*","MeshInstance3D",true,false)[0]
  print(id," binds:")
  for b in mesh.skin.get_bind_count():print(b," ",mesh.skin.get_bind_name(b)," / ",mesh.skin.get_bind_bone(b))
  var sk:Skeleton3D=scene.find_child("Skeleton3D",true,false)
  print("HEAD GLOBAL ",sk.global_transform*sk.get_bone_global_pose(sk.find_bone("Head")))
  scene.free()
 quit()
