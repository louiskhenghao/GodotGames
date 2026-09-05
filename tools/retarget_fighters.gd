extends SceneTree
## EXPERIMENT ONLY: differing bind poses still need manual calibration. Not used by the game.
## Sample shared clips onto the supplied rigs to expose retargeting problems.
const MAP:={"Hips":"pelvis","Spine":"spine_01","Spine1":"spine_02","Spine2":"spine_03","Neck":"neck_01","Head":"Head","LeftShoulder":"clavicle_l","LeftArm":"upperarm_l","LeftForeArm":"lowerarm_l","LeftHand":"hand_l","RightShoulder":"clavicle_r","RightArm":"upperarm_r","RightForeArm":"lowerarm_r","RightHand":"hand_r","LeftUpLeg":"thigh_l","LeftLeg":"calf_l","LeftFoot":"foot_l","LeftToeBase":"ball_l","RightUpLeg":"thigh_r","RightLeg":"calf_r","RightFoot":"foot_r","RightToeBase":"ball_r"}
func _initialize():call_deferred("run")
func run():
 var source:=RushBoxer.new();root.add_child(source);source.build(true)
 var src:=source.skeleton
 print("Source bones: ",range(src.get_bone_count()).map(func(i):return src.get_bone_name(i)))
 for file in ["candidate","candidate_b"]:
  var model:Node3D=load("res://assets/fighters/custom/"+file+"_preview.scn").instantiate()
  root.add_child(model)
  var target:Skeleton3D=model.find_child("Skeleton3D",true,false)
  var animator:AnimationPlayer=model.find_child("AnimationPlayer",true,false)
  animator.stop()
  target.reset_bone_poses()
  var target_rest:=[]
  for i in target.get_bone_count():target_rest.append(target.get_bone_global_rest(i))
  var library:=AnimationLibrary.new()
  for clip in ["Idle","Jog_Fwd","Punch_Jab","Punch_Cross","Hit_Chest","Death01","Jump_Land"]:
   var old:Animation=source.animator.get_animation(clip)
   var animation:=Animation.new();animation.length=old.length;animation.loop_mode=old.loop_mode
   var tracks:={}
   for bone in target.get_bone_count():
    var mapped:String=MAP.get(target.get_bone_name(bone),"")
    var index:=src.find_bone(mapped)
    if index<0:continue
    var track:=animation.add_track(Animation.TYPE_ROTATION_3D)
    animation.track_set_path(track,NodePath(str(animator.get_node(animator.root_node).get_path_to(target))+":"+target.get_bone_name(bone)))
    tracks[bone]={"track":track,"source":index}
   var count:=maxi(2,ceili(old.length*24))
   for frame in count+1:
    var time:=minf(old.length,frame*old.length/count)
    source.animator.play(clip);source.animator.seek(time,true);src.force_update_all_bone_transforms()
    var globals:=[]
    for bone in target.get_bone_count():
     var parent:=target.get_bone_parent(bone)
     var parent_basis:Basis=globals[parent] if parent>=0 else Basis.IDENTITY
     var global_basis:Basis=parent_basis*target.get_bone_rest(bone).basis.orthonormalized()
     if tracks.has(bone):
      var index:int=tracks[bone].source
      var delta:=src.get_bone_global_pose(index).basis.orthonormalized()*src.get_bone_global_rest(index).basis.orthonormalized().inverse()
      global_basis=delta*target_rest[bone].basis.orthonormalized()
      var local:Basis=parent_basis.inverse()*global_basis
      animation.rotation_track_insert_key(tracks[bone].track,time,local.get_rotation_quaternion())
     globals.append(global_basis)
   library.add_animation(clip,animation)
  for name in animator.get_animation_library_list():animator.remove_animation_library(name)
  animator.add_animation_library("",library)
  animator.play("Idle");animator.advance(0)
  var packed:=PackedScene.new();packed.pack(model)
  var error:=ResourceSaver.save(packed,"res://assets/fighters/custom/"+file+"_combat.scn",ResourceSaver.FLAG_COMPRESS)
  print(file," combat retarget saved ",error," clips ",animator.get_animation_list())
  model.queue_free();await process_frame
 source.queue_free();await process_frame
 quit()
