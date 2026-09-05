class_name RushActionButton
extends Button
var accent:=Color("55dfc3")
var glyph: RushIcon
var caption:="DODGE"
var meter:=1.0
var value:=""
func setup(kind: String, color: Color, title: String, diameter: float, action: Callable) -> void:
	accent=color
	caption=title
	custom_minimum_size=Vector2(diameter,diameter+22)
	size=custom_minimum_size
	tooltip_text=title
	for state in ["normal","hover","pressed","disabled","focus"]:add_theme_stylebox_override(state,StyleBoxEmpty.new())
	glyph=RushIcon.new()
	glyph.kind=kind
	glyph.tint=accent
	glyph.position=Vector2.ONE*(diameter*.5-18)
	glyph.size=Vector2(36,36)
	add_child(glyph)
	pressed.connect(action)
func _has_point(point: Vector2) -> bool:
	return point.distance_to(Vector2.ONE*size.x*.5)<=size.x*.5
func _process(_delta: float) -> void:
	glyph.visible=value.is_empty()
	queue_redraw()
func _draw() -> void:
	var center:=Vector2.ONE*size.x*.5
	var r:=size.x*.5-4
	draw_circle(center+Vector2(0,3),r+3,Color(0,0,0,.22))
	draw_circle(center,r,Color("152433") if not button_pressed else Color("30485b"))
	draw_arc(center,r,0,TAU,64,accent.darkened(.62),2,true)
	draw_arc(center,r,-PI*.5,-PI*.5+TAU*clampf(meter,.001,1),64,accent,3,true)
	if has_focus():draw_arc(center,r+3,0,TAU,64,Color("f6ecd5"),2,true)
	var font:=get_theme_default_font()
	if not value.is_empty():
		var width:=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x
		draw_string(font,center+Vector2(-width*.5,7),value,HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("f7eedb"))
	var text_width:=font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
	draw_string(font,Vector2(center.x-text_width*.5,size.x+15),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("cfdbdd"))
