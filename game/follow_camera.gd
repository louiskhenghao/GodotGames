class_name RushFollowCamera
extends RefCounted
## A small dead zone preserves punch framing; the world scrolls as the player travels.
var focus:=Vector3.ZERO
var initialized:=false
const OFFSET:=Vector3(16,22,16)
func update(camera:Camera3D,player:Vector3,viewport:Vector2,delta:float,snap:bool=false,shake:float=0) -> void:
	var aim:=player+Vector3.UP*.9
	if snap or not initialized:
		focus=aim
		initialized=true
	else:
		var offset:=aim-focus
		var target:=aim-offset.normalized()*minf(.55,offset.length())
		focus=focus.lerp(target,1-exp(-10*delta))
	var aspect:=viewport.x/maxf(1,viewport.y)
	camera.size=12.5*clampf(aspect/(540.0/960.0),1,1.9)
	camera.position=focus+OFFSET
	camera.look_at(focus)
	camera.position-=camera.basis.y*camera.size*.09
	if shake>0:camera.position+=camera.basis.x*randf_range(-shake,shake)+camera.basis.y*randf_range(-shake,shake)*.4
