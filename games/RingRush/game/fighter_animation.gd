class_name RushFighterAnimation
extends AnimationTree
## Lower-body locomotion continues under filtered upper-body attacks. No attack root motion.
var attack_clip:=AnimationNodeAnimation.new()
var hit_clip:=AnimationNodeAnimation.new()
func setup(player:AnimationPlayer):
 anim_player=get_path_to(player)
 root_node=get_path_to(player.get_node(player.root_node))
 callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 var graph:=AnimationNodeBlendTree.new()
 var idle:=AnimationNodeAnimation.new();idle.animation="Idle";graph.add_node("idle",idle)
 var run:=AnimationNodeAnimation.new();run.animation="Jog_Fwd";graph.add_node("run",run)
 var locomotion:=AnimationNodeBlend2.new();graph.add_node("locomotion",locomotion)
 graph.connect_node("locomotion",0,"idle");graph.connect_node("locomotion",1,"run")
 attack_clip.animation="Punch_Jab";graph.add_node("attack",attack_clip)
 hit_clip.animation="Hit_Chest";graph.add_node("hit",hit_clip)
 var speed:=AnimationNodeTimeScale.new();graph.add_node("speed",speed);graph.connect_node("speed",0,"attack")
 var shot:=AnimationNodeOneShot.new();shot.fadein_time=.05;shot.fadeout_time=.12;shot.filter_enabled=true
 var hurt:=AnimationNodeOneShot.new();hurt.fadein_time=.04;hurt.fadeout_time=.1;hurt.filter_enabled=true
 var animation:=player.get_animation("Punch_Jab")
 for i in animation.get_track_count():
  var track:NodePath=animation.track_get_path(i);var bone:=str(track.get_subname(0)) if track.get_subname_count()>0 else ""
  if bone.is_empty() or bone in ["root","pelvis"] or bone.begins_with("thigh") or bone.begins_with("calf") or bone.begins_with("foot") or bone.begins_with("ball"):continue
  shot.set_filter_path(track,true);hurt.set_filter_path(track,true)
 graph.add_node("strike",shot);graph.connect_node("strike",0,"locomotion");graph.connect_node("strike",1,"speed")
 graph.add_node("hurt",hurt);graph.connect_node("hurt",0,"strike");graph.connect_node("hurt",1,"hit");graph.connect_node("output",0,"hurt")
 tree_root=graph;set("parameters/speed/scale",1.7);active=true
func pose(delta:float,moving:bool):
 set("parameters/locomotion/blend_amount",move_toward(float(get("parameters/locomotion/blend_amount")),1 if moving else 0,delta*10))
 advance(delta)
func punch(cross:bool):
 attack_clip.animation="Punch_Cross" if cross else "Punch_Jab"
 set("parameters/strike/request",AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
func hurt():set("parameters/hurt/request",AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
