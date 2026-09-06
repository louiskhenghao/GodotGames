class_name RushVenueMap
extends Control
var stage:=0
func _draw() -> void:
	var poly:=RushArenaLayout.polygon(stage)
	var extent:=Vector2.ONE
	for p in poly:extent=extent.max(p.abs())
	var factor:=minf((size.x-16)/(extent.x*2),(size.y-16)/(extent.y*2))
	var display:=PackedVector2Array()
	for p in poly:display.append(size*.5+p*factor)
	draw_colored_polygon(display,Color("1b343e"))
	display.append(display[0])
	draw_polyline(display,Color("61cfbd"),2,true)
	for b in RushArenaLayout.blockers(stage):
		draw_circle(size*.5+Vector2(b.x,b.y)*factor,b.z*factor,Color("b9a282"))
	draw_circle(size*.5,4,Color("f1e7ce"))
