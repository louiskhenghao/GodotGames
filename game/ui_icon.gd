class_name RushIcon
extends Control
var kind := "fist"
var tint := Color("4de1c6")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(32, 32)

func _draw() -> void:
	var factor := minf(size.x, size.y) / 32.0
	draw_set_transform(size * 0.5 - Vector2.ONE * 16 * factor, 0, Vector2.ONE * factor)
	match kind:
		"fist":
			line([Vector2(9,25),Vector2(6,15),Vector2(9,9),Vector2(14,9),Vector2(15,6),Vector2(23,6),Vector2(27,11),Vector2(26,20),Vector2(21,25),Vector2(9,25)])
			line([Vector2(10,25),Vector2(11,29),Vector2(21,29),Vector2(22,25)])
			line([Vector2(12,11),Vector2(13,17),Vector2(18,17)])
		"bolt": polygon([Vector2(18,2),Vector2(7,18),Vector2(15,18),Vector2(12,30),Vector2(27,12),Vector2(18,12)])
		"dash":
			line([Vector2(13,7),Vector2(23,16),Vector2(13,25)])
			line([Vector2(4,16),Vector2(23,16)])
			line([Vector2(3,8),Vector2(8,8)])
			line([Vector2(3,24),Vector2(8,24)])
		"shield": line([Vector2(16,3),Vector2(27,7),Vector2(25,21),Vector2(16,29),Vector2(7,21),Vector2(5,7),Vector2(16,3)])
		"heart": line([Vector2(16,27),Vector2(5,16),Vector2(4,10),Vector2(8,5),Vector2(13,5),Vector2(16,9),Vector2(19,5),Vector2(24,5),Vector2(28,10),Vector2(27,16),Vector2(16,27)])
		"target":
			draw_arc(Vector2(16,16),10,0,TAU,36,tint,2,true)
			draw_circle(Vector2(16,16),3,tint)
			for a in [0,PI/2,PI,PI*1.5]: line([Vector2(16,16)+Vector2.from_angle(a)*8,Vector2(16,16)+Vector2.from_angle(a)*15])
		"nova", "orbit":
			draw_arc(Vector2(16,16),11,0,TAU,36,tint,2,true)
			draw_arc(Vector2(16,16),5,0,TAU,24,tint,2,true)
			draw_circle(Vector2(25,9),4,tint)
		"flame": line([Vector2(16,2),Vector2(18,12),Vector2(24,8),Vector2(27,19),Vector2(23,27),Vector2(10,28),Vector2(5,21),Vector2(8,12),Vector2(11,16),Vector2(16,2)])
		"snow":
			for a in [0,PI/3,PI*2/3]: line([Vector2(16,16)-Vector2.from_angle(a)*13,Vector2(16,16)+Vector2.from_angle(a)*13])
		"magnet": line([Vector2(6,4),Vector2(6,20),Vector2(10,27),Vector2(22,27),Vector2(26,20),Vector2(26,4),Vector2(20,4),Vector2(20,20),Vector2(12,20),Vector2(12,4),Vector2(6,4)])
		"crown": line([Vector2(5,25),Vector2(3,8),Vector2(11,15),Vector2(16,4),Vector2(21,15),Vector2(29,8),Vector2(27,25),Vector2(5,25)])
		"coin":
			draw_arc(Vector2(16,16),12,0,TAU,32,tint,2,true)
			line([Vector2(16,7),Vector2(22,16),Vector2(16,25),Vector2(10,16),Vector2(16,7)])
		"back": line([Vector2(20,6),Vector2(10,16),Vector2(20,26)])
		"pause":
			draw_rect(Rect2(8,6,5,20),tint)
			draw_rect(Rect2(20,6,5,20),tint)
		"gear":
			draw_arc(Vector2(16,16),8,0,TAU,24,tint,2,true)
			for i in 8:
				var v := Vector2.from_angle(i*TAU/8)
				line([Vector2(16,16)+v*8,Vector2(16,16)+v*13])
		"lock":
			draw_rect(Rect2(7,13,18,15),tint,false,2)
			draw_arc(Vector2(16,12),7,PI,TAU,24,tint,2,true)
		"book":
			line([Vector2(16,8),Vector2(5,5),Vector2(5,25),Vector2(16,28),Vector2(27,25),Vector2(27,5),Vector2(16,8),Vector2(16,28)])
		_: draw_arc(Vector2(16,16),11,0,TAU,32,tint,2,true)

func line(points: Array) -> void:
	draw_polyline(PackedVector2Array(points), tint, 2.2, true)

func polygon(points: Array) -> void:
	draw_colored_polygon(PackedVector2Array(points),tint)
