class_name CoreAdBreak
extends CanvasLayer
## Explicit development creative. Production ad duration/close controls belong to the SDK.
signal closed(earned: bool)
var elapsed:=0.0
var duration:=15.0
var minimum_close:=5.0
var rewarded:=true
var finished:=false
var close_button:Button
var progress:ProgressBar
var countdown:Label
func _ready() -> void:
	layer=100
	var root:=ColorRect.new()
	root.color=Color("0c1420")
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var col:=VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.anchor_top=.16
	col.anchor_bottom=.87
	col.offset_left=32
	col.offset_right=-32
	col.add_theme_constant_override("separation",22)
	root.add_child(col)
	var heading:=Label.new()
	heading.text="TEST ADVERTISEMENT"
	heading.add_theme_font_size_override("font_size",18)
	heading.add_theme_color_override("font_color",Color("adbecd"))
	col.add_child(heading)
	var creative:=Label.new()
	creative.text="PLAY.\nEXPLORE.\nENJOY."
	creative.add_theme_font_size_override("font_size",56)
	creative.add_theme_color_override("font_color",Color("f2cf83"))
	col.add_child(creative)
	var info:=Label.new()
	info.text="Development preview. No real advertiser.\nWatch to the end to receive your reward." if rewarded else "Development preview. No real advertiser.\nYour progress is safely paused."
	info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size",18)
	col.add_child(info)
	progress=ProgressBar.new()
	progress.custom_minimum_size.y=8
	progress.show_percentage=false
	col.add_child(progress)
	countdown=Label.new()
	countdown.add_theme_font_size_override("font_size",20)
	col.add_child(countdown)
	close_button=Button.new()
	close_button.custom_minimum_size.y=60
	close_button.add_theme_font_size_override("font_size",20)
	close_button.pressed.connect(request_close)
	col.add_child(close_button)
	_refresh()
func _process(delta:float) -> void:
	if DisplayServer.get_name()!="headless" and DisplayServer.window_is_focused(): advance(delta)
func advance(delta:float) -> void:
	if finished:return
	elapsed=minf(duration,elapsed+maxf(0,delta))
	_refresh()
func _refresh() -> void:
	progress.value=elapsed/duration*100
	close_button.disabled=elapsed<minimum_close
	close_button.text="CLOSE IN %ds"%ceili(minimum_close-elapsed) if elapsed<minimum_close else ("CLAIM & CLOSE" if rewarded and elapsed>=duration else ("CLOSE WITHOUT REWARD" if rewarded else "CLOSE"))
	countdown.text="Reward ready" if rewarded and elapsed>=duration else "%ds remaining"%ceili(duration-elapsed)
func request_close() -> void:
	if finished or elapsed<minimum_close:return
	finished=true
	closed.emit(rewarded and elapsed>=duration)
	queue_free()
func _unhandled_key_input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		request_close()
		get_viewport().set_input_as_handled()
