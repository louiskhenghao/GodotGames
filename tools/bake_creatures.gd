extends SceneTree
const CLIPS:=["Idle","Jog_Fwd","Punch_Jab","Punch_Cross","Hit_Chest","Death01"]
func _initialize():call_deferred("run")
func run():
 if DisplayServer.get_name()=="headless":push_error("Native renderer required");quit(1);return
 for id in ["rattle","shade","hex"]:
  var fighter:=RushBoxer.new();root.add_child(fighter);fighter.build(true);fighter.set_character(id)
  var library:=RushCrowdLibrary.new()
  for clip in CLIPS:
   var duration:float=fighter.animator.get_animation(clip).length
   var count:int=1 if clip=="Idle" else (18 if clip=="Death01" else maxi(2,ceili(duration*24)))
   library.clips[clip]=[];library.durations[clip]=duration
   for frame in count:
    fighter.animator.play(clip);fighter.animator.seek(frame*duration/count,true)
    fighter.skeleton.force_update_all_bone_transforms();await process_frame
    var result:=ArrayMesh.new()
    var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for mesh:MeshInstance3D in fighter.body.find_children("*","MeshInstance3D",true,false):
     if mesh in fighter.gloves:continue
     var baked:Mesh=mesh.bake_mesh_from_current_skeleton_pose() if mesh.skin!=null else mesh.mesh
     if baked==null:continue
     var transform:Transform3D=fighter.body.global_transform.affine_inverse()*mesh.global_transform
     for part in baked.get_surface_count():surface.append_from(baked,part,transform)
    surface.index();surface.commit(result)
    surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for glove in fighter.gloves:surface.append_from(glove.mesh,0,fighter.body.global_transform.affine_inverse()*glove.global_transform)
    surface.index();surface.commit(result)
    library.clips[clip].append(result)
   print(id," ",clip," ",count," poses")
  print("saved ",ResourceSaver.save(library,"res://assets/fighters/crowd_"+id+".res",ResourceSaver.FLAG_COMPRESS))
  fighter.queue_free();await process_frame
 quit()
