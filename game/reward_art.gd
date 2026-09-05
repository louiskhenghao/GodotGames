class_name RushRewardArt
extends Control
## Lightweight vector rewards, shared by store and training cards.
var kind:="coin"
var tint:=Color("ffc466")
var level:=-1
func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 resized.connect(queue_redraw)
 if not kind.begins_with("coins_"):
  var symbol:=RushIcon.new();symbol.kind=kind;symbol.tint=tint
  symbol.custom_minimum_size=Vector2(60,60)
  add_child(symbol)
  symbol.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
  symbol.offset_left=-30;symbol.offset_right=30;symbol.offset_top=-35;symbol.offset_bottom=25
func _draw() -> void:
 var center:=size*.5
 if kind.begins_with("coins_"):
  var stacks:int={"coins_500":2,"coins_1500":3,"coins_4000":4}.get(kind,2)
  for stack in stacks:
   var x:=center.x+(stack-(stacks-1)*.5)*26
   var height:int=2+stack+(1 if stacks==4 else 0)
   for coin in height:
    var at:=Vector2(x,size.y-12-coin*9)
    draw_set_transform(at,0,Vector2(1,.46))
    draw_circle(Vector2.ZERO,19,Color("ba702c"))
    draw_circle(Vector2(0,-5),19,tint)
    draw_arc(Vector2(0,-5),13,0,TAU,28,Color("fff0b0"),2,true)
  draw_set_transform(Vector2.ZERO)
  for at in [Vector2(center.x-62,23),Vector2(center.x+66,40)]:
   draw_line(at-Vector2(5,0),at+Vector2(5,0),Color("fff3b6"),2,true)
   draw_line(at-Vector2(0,5),at+Vector2(0,5),Color("fff3b6"),2,true)
 else:
  draw_circle(center-Vector2(0,5),minf(34,size.y*.45),Color(tint,.10))
 if level>=0:
  for i in 5:draw_style_box(_pip(i<level),Rect2(center.x-42+i*18,size.y-6,12,5))
func _pip(active:bool) -> StyleBoxFlat:
 var style:=StyleBoxFlat.new();style.bg_color=tint if active else Color("344c64");style.set_corner_radius_all(2);return style
