class_name RushMenuBackdrop
extends Control
## Opaque, lightweight stadium backdrop. Menu transitions cannot expose the actor.
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("0b1724"))
	var horizon:=size.y*.42
	for side in [-1,1]:
		var origin:=Vector2(size.x*(.08 if side<0 else .92),size.y*.10)
		var beam:=PackedVector2Array([origin+Vector2(-12,0),origin+Vector2(12,0),Vector2(size.x*(.68 if side<0 else .86),size.y*.84),Vector2(size.x*(.14 if side<0 else .32),size.y*.84)])
		draw_colored_polygon(beam,Color(.20,.40,.49,.065))
		for i in 4:
			draw_rect(Rect2(origin+Vector2(i*9-18,-3),Vector2(5,6)),Color("314858"))
	for i in 7:
		var y:=horizon+i*i*size.y*.011
		draw_line(Vector2(0,y),Vector2(size.x,y),Color("132534"),1)
	for i in range(-4,5):
		draw_line(Vector2(size.x*.5,horizon),Vector2(size.x*.5+i*size.x*.32,size.y),Color("122330"),1)
