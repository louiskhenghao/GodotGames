class_name RushCreatureModel
extends Node3D
## Selected CC0 Quaternius models, baked from their native skeletal animations.
const TYPES:=["drone","spitter","hound","wisp","stinger","sentry"]
const MODELS:={"drone":"drone","spitter":"spitter","hound":"wolf","wisp":"wisp","helper":"helper","fox":"fox","shiba":"shiba","bee":"bee","stinger":"bee","sentry":"helper"}
static var libraries:Dictionary={}
var shell:MeshInstance3D
var library:RushCrowdLibrary
var kind:="drone"
var clip:="Idle"
var clip_time:=0.0
var last_clock:=-1.0
func _init():
 shell=MeshInstance3D.new();add_child(shell)
 var mat:=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true;mat.roughness=.75
 shell.material_override=mat
static func prewarm():
 for id in MODELS:
  if not libraries.has(id):libraries[id]=load("res://assets/creatures/"+MODELS[id]+".res")
func configure(id:String):
 kind=id;prewarm();library=libraries[id]
 position.y=.65 if kind in ["drone","wisp","helper","bee","stinger","sentry"] else 0.0
 shell.mesh=library.clips.Idle[0];rotation=Vector3.ZERO;clip="Idle";clip_time=0;last_clock=-1
 set_alpha(1)
func set_alpha(value:float):
 shell.material_override.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED if value>=1 else BaseMaterial3D.TRANSPARENCY_ALPHA
 shell.material_override.albedo_color=Color(1,1,1,value)
func animate(clock:float,moving:bool,hit:float,attack:float=0):
 if library==null:return
 var delta:float=maxf(0,clock-last_clock) if last_clock>=0 else 0.0;last_clock=clock
 var next:String="Attack" if attack>0 else ("Hit" if hit>0 else ("Run" if moving else "Idle"))
 if next!=clip:clip=next;clip_time=0
 clip_time+=delta
 position.y=.65 if kind in ["drone","wisp","helper","bee","stinger","sentry"] else 0.0
 var frames:Array=library.clips[clip];var duration:float=library.durations[clip]
 shell.mesh=frames[mini(frames.size()-1,int(fmod(clip_time,duration)/duration*frames.size()))]
func death_pose(seconds:float):
 if library==null:return
 var frames:Array=library.clips.Death
 shell.mesh=frames[mini(frames.size()-1,int(clampf(seconds/.85,0,1)*(frames.size()-1)))]
 position.y=lerpf(.65,0,minf(1,seconds*1.8)) if kind in ["drone","wisp","helper","bee","stinger","sentry"] else 0.0
