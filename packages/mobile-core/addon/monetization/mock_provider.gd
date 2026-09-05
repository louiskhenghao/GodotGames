extends CoreCommerceProvider
## Development only. Visible timer-based ad simulation; no SDK or real charge.
var fail_next:=false
var active:CoreAdBreak
var active_id:=""
var banner:CanvasLayer
var banner_panel:ColorRect
var banner_requested:=false
func _init() -> void:is_mock=true
func show_rewarded(request_id:String,_placement:String) -> void:
	_present(request_id,true)
func show_interstitial(request_id:String,_placement:String) -> void:
	_present(request_id,false)
func _present(request_id:String,rewarded:bool) -> void:
	if fail_next:
		fail_next=false
		if rewarded:ad_finished.emit(request_id,false,"No ad available. Try again later.")
		else:interstitial_finished.emit(request_id,false,"No ad available.")
		return
	if is_instance_valid(active):
		if rewarded:ad_finished.emit(request_id,false,"An ad is already open.")
		else:interstitial_finished.emit(request_id,false,"An ad is already open.")
		return
	active_id=request_id
	active=CoreAdBreak.new()
	active.rewarded=rewarded
	active.duration=15 if rewarded else 5
	active.minimum_close=5
	add_child(active)
	if banner!=null:banner.visible=false
	active.closed.connect(func(earned:bool):
		active=null
		active_id=""
		if banner!=null:banner.visible=banner_requested
		if rewarded:ad_finished.emit(request_id,earned,"Reward earned." if earned else "Ad closed early. No reward granted.")
		else:interstitial_finished.emit(request_id,true,"Ad closed."))
func cancel(request_id:String) -> void:
	if active_id!=request_id:return
	if is_instance_valid(active):active.queue_free()
	active=null
	active_id=""
	if banner!=null:banner.visible=banner_requested
func set_banner(visible:bool) -> void:
	banner_requested=visible
	if banner==null and visible:
		banner=CanvasLayer.new()
		banner.layer=20
		add_child(banner)
		var background:=ColorRect.new()
		banner_panel=background
		background.color=Color("13232e")
		background.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		background.offset_top=-48
		background.offset_bottom=0
		background.mouse_filter=Control.MOUSE_FILTER_STOP
		banner.add_child(background)
		var label:=Label.new()
		label.text="ADVERTISEMENT  ·  DEVELOPMENT TEST BANNER"
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size",11)
		label.add_theme_color_override("font_color",Color("aebec7"))
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		background.add_child(label)
		get_viewport().size_changed.connect(_layout_banner)
		_layout_banner()
	if banner!=null:banner.visible=visible and not is_instance_valid(active)
func _layout_banner() -> void:
	if banner_panel==null:return
	if not (OS.has_feature("android") or OS.has_feature("ios")):return
	var safe:=DisplayServer.get_display_safe_area()
	var window:=DisplayServer.window_get_size()
	var logical:=get_viewport().get_visible_rect().size
	if window.x<=0 or window.y<=0 or safe.size.x<=0:return
	var bottom:float=(window.y-safe.end.y)*logical.y/window.y
	banner_panel.offset_left=safe.position.x*logical.x/window.x
	banner_panel.offset_right=-(window.x-safe.end.x)*logical.x/window.x
	banner_panel.offset_top=-48-bottom
	banner_panel.offset_bottom=-bottom
func purchase(request_id:String,product:String) -> void:
	await get_tree().create_timer(.6).timeout
	var success:=not fail_next
	fail_next=false
	purchase_finished.emit(request_id,product,"mock:"+request_id,success,"Test purchase completed." if success else "Test purchase cancelled.")
func restore(request_id:String) -> void:
	await get_tree().create_timer(.4).timeout
	restore_finished.emit(request_id,[],true,"Test store: local unlocks are already saved.")
