extends SceneTree
func _initialize():call_deferred("run")
func visit(node:Node, report:Dictionary):
 if node is MeshInstance3D and node.mesh!=null:
  var mesh:Mesh=node.mesh
  var item:={"name":node.name,"vertices":0,"triangles":0,"skin":node.skin!=null,"surfaces":mesh.get_surface_count(),"materials":[]}
  for i in mesh.get_surface_count():
   item.vertices+=mesh.surface_get_array_len(i)
   item.triangles+=mesh.surface_get_array_index_len(i)/3 if mesh.surface_get_array_index_len(i)>0 else mesh.surface_get_array_len(i)/3
   var m=node.get_active_material(i)
   item.materials.append({"name":m.resource_name if m else "none","texture":str(m.albedo_texture.get_size()) if m is BaseMaterial3D and m.albedo_texture!=null else "none"})
  report.meshes.append(item)
 if node is Skeleton3D:
  report.skeletons.append(node.get_bone_count())
  report.bones=[]
  for i in node.get_bone_count():report.bones.append(node.get_bone_name(i))
 if node is AnimationPlayer:
  for clip in node.get_animation_list():
   var anim:Animation=node.get_animation(clip)
   report.animations.append({"name":clip,"duration":anim.length,"tracks":anim.get_track_count()})
 for child in node.get_children():visit(child,report)
func run():
 var reports:=[]
 var folder:="res://docs/model-review/"
 DirAccess.make_dir_recursive_absolute(folder)
 root.size=Vector2i(900,900)
 for file in ["candidate","candidate_b"]:
  var scene=load("res://assets/fighters/custom/"+file+("_combat.scn" if "--combat" in OS.get_cmdline_user_args() else ("_preview.scn" if "--optimized" in OS.get_cmdline_user_args() else ".fbx")))
  if scene==null:continue
  var model=scene.instantiate()
  root.add_child(model)
  var report:={"file":file,"meshes":[],"skeletons":[],"animations":[]}
  visit(model,report)
  print(JSON.stringify(report))
  reports.append(report)
  if DisplayServer.get_name()!="headless":
   var bounds:=AABB()
   for mesh in model.find_children("*","MeshInstance3D",true,false):bounds=bounds.merge(mesh.global_transform*mesh.get_aabb())
   var camera:=Camera3D.new();root.add_child(camera)
   camera.projection=Camera3D.PROJECTION_ORTHOGONAL
   camera.size=maxf(bounds.size.y,bounds.size.x)*1.3
   var center:=bounds.get_center()
   camera.position=center+Vector3(.4,.12,1).normalized()*maxf(3,bounds.size.length()*2)
   camera.look_at(center)
   var key:=DirectionalLight3D.new();root.add_child(key);key.rotation_degrees=Vector3(-35,-35,0);key.light_energy=1.4
   var fill:=DirectionalLight3D.new();root.add_child(fill);fill.rotation_degrees=Vector3(20,145,0);fill.light_energy=.8
   for angle in [0,1,2,3]:
    var animator:AnimationPlayer=model.find_child("AnimationPlayer",true,false)
    if animator!=null:
     animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
     animator.play(["Idle","Jog_Fwd","Punch_Jab","Punch_Cross"][angle] if "--combat" in OS.get_cmdline_user_args() else animator.get_animation_list()[0]);animator.seek(.28 if "--combat" in OS.get_cmdline_user_args() else angle*2.5,true)
    await create_timer(.3).timeout
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(folder+file+("_combat" if "--combat" in OS.get_cmdline_user_args() else ("_optimized" if "--optimized" in OS.get_cmdline_user_args() else ""))+"_"+str(angle)+".png")
   camera.queue_free();key.queue_free();fill.queue_free()
  model.queue_free()
  await process_frame
 FileAccess.open(folder+("combat-experiment.json" if "--combat" in OS.get_cmdline_user_args() else ("optimized-inspection.json" if "--optimized" in OS.get_cmdline_user_args() else "inspection.json")),FileAccess.WRITE).store_string(JSON.stringify(reports,"\t"))
 quit()
