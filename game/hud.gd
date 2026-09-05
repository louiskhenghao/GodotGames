class_name RushHUD
extends CanvasLayer
const INK := Color("0d1826")
const PAPER := Color("f8f0dc")
const MUTED := Color("a9bac8")
const TEAL := Color("4de1c6")
const AMBER := Color("ffc466")
const DISPLAY = preload("res://assets/fonts/BarlowCondensed-Bold.ttf")
var game: Node3D
var root: Control
var screen: Control
var stick: CoreVirtualStick
var stats: Label
var health_bar: ProgressBar
var xp_bar: ProgressBar
var boss_bar: ProgressBar
var boss_title: Label
var hp_text: Label
var combo_text: Label
var hint: Label
var message: Label
var dash_button: Button
var technique_button: Button
var special_button: Button
var buttons: Array[Button] = []
var fighter_index:=0
var move_index:=0
var rotation_finger:=-1
var mouse_rotating:=false
var upgrade_overlay:Control
var upgrade_panel:PanelContainer
var upgrade_tween:Tween
var upgrade_closing:=false
var venue_index:=0
var current_page := "home"
var page_body: VBoxContainer
var toast_time := 0.0
var touch_device := OS.has_feature("android") or OS.has_feature("ios")
var transition: Tween

func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	stick = CoreVirtualStick.new()
	stick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(stick)
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(screen)
	message = label("", 17, PAPER)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	message.anchor_top=.14
	message.anchor_bottom=.14
	message.offset_left = 24
	message.offset_right = -24
	message.offset_top = 0
	message.offset_bottom = 64
	message.mouse_filter=Control.MOUSE_FILTER_IGNORE
	message.add_theme_stylebox_override("normal", style(Color("183b3e"), 8))
	message.visible = false
	root.add_child(message)
	MobileCore.commerce.completed.connect(_commerce_completed)
	MobileCore.commerce.busy_changed.connect(_busy)
	get_viewport().size_changed.connect(_safe_area)
	_safe_area()

func _safe_area() -> void:
	if current_page == "playing": call_deferred("_block_actions")
	if not (OS.has_feature("android") or OS.has_feature("ios")): return
	var safe := DisplayServer.get_display_safe_area()
	var window := DisplayServer.window_get_size()
	var logical := get_viewport().get_visible_rect().size
	if window.x <= 0 or window.y <= 0 or safe.size.x <= 0: return
	root.offset_left = safe.position.x * logical.x / window.x
	root.offset_top = safe.position.y * logical.y / window.y
	root.offset_right = -(window.x-safe.end.x) * logical.x / window.x
	root.offset_bottom = -(window.y-safe.end.y) * logical.y / window.y

func _process(delta: float) -> void:
	for b in buttons:
		if not is_instance_valid(b) or not b.has_meta("glyph"): continue
		var symbol: RushIcon = b.get_meta("glyph")
		var color: Color = MUTED if b.disabled else b.get_meta("glyph_tint")
		if symbol.tint != color:
			symbol.tint = color
			symbol.queue_redraw()
	if toast_time > 0:
		toast_time -= delta
		message.visible = toast_time > 0

func _input(event: InputEvent) -> void:
	if current_page in ["fighters","home"]:
		if event is InputEventScreenTouch:
			if event.pressed and rotation_finger<0 and _rotation_area().has_point(event.position):
				rotation_finger=event.index
				get_viewport().set_input_as_handled()
			elif not event.pressed and event.index==rotation_finger:rotation_finger=-1
		elif event is InputEventScreenDrag and event.index==rotation_finger:
			game.player.rotation.y+=event.relative.x*.012
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
			mouse_rotating=event.pressed and _rotation_area().has_point(event.position)
		elif event is InputEventMouseMotion and mouse_rotating:
			game.player.rotation.y+=event.relative.x*.012
			get_viewport().set_input_as_handled()
		elif current_page=="fighters" and event is InputEventKey and event.pressed and not event.echo:
			if event.keycode==KEY_LEFT:cycle_fighter(-1)
			elif event.keycode==KEY_RIGHT:cycle_fighter(1)
	# A second finger can use skills while the first finger steers.
	if current_page != "playing" or not event is InputEventScreenTouch or not event.pressed: return
	for b in buttons:
		if is_instance_valid(b) and not b.disabled and b.get_global_rect().has_point(event.position):
			b.pressed.emit()
			get_viewport().set_input_as_handled()
			return

func _rotation_area() -> Rect2:
	return Rect2(root.global_position+root.size*Vector2(.20,.15),root.size*Vector2(.60,.40))

func style(color: Color, radius: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s

func label(text: String, size: int = 22, color: Color = PAPER, display: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	if display: node.add_theme_font_override("font", DISPLAY)
	return node

func icon(kind: String, tint: Color = TEAL, dimension: int = 32) -> RushIcon:
	var node := RushIcon.new()
	node.kind = kind
	node.tint = tint
	node.custom_minimum_size = Vector2.ONE * dimension
	return node

func button(text: String, action: Callable, primary: bool = false, glyph: String = "") -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 60
	node.add_theme_font_override("font", DISPLAY)
	node.add_theme_font_size_override("font_size", 24)
	var color := AMBER if primary else Color("203346")
	var normal := style(color)
	if not glyph.is_empty(): normal.content_margin_left = 53
	node.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = color.lightened(0.10)
	node.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = color.darkened(0.12)
	node.add_theme_stylebox_override("pressed", pressed)
	var disabled := normal.duplicate()
	disabled.bg_color = Color("172536")
	node.add_theme_stylebox_override("disabled", disabled)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.set_border_width_all(2)
	focus.border_color = TEAL
	focus.set_corner_radius_all(12)
	node.add_theme_stylebox_override("focus", focus)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		node.add_theme_color_override(state, INK if primary else PAPER)
	node.add_theme_color_override("font_disabled_color", MUTED)
	if not glyph.is_empty():
		var symbol := icon(glyph, INK if primary else TEAL)
		node.add_child(symbol)
		symbol.position = Vector2(16, 14)
		symbol.size = Vector2(28,28)
		node.set_meta("glyph",symbol)
		node.set_meta("glyph_tint",symbol.tint)
	if action.is_valid(): node.pressed.connect(action)
	buttons.append(node)
	return node

func clear(page_name: String = "") -> void:
	_remove_upgrade()
	rotation_finger=-1
	mouse_rotating=false
	toast_time=0
	message.visible=false
	game.player.visible=page_name in ["home","fighters","move_demo","playing"]
	game.podium.visible=game.mode=="home" and page_name in ["home","fighters","move_demo"]
	game.arena.showcase.visible=game.podium.visible
	MobileCore.commerce.provider.set_banner(false)
	if not page_name.is_empty(): current_page = page_name
	if transition != null: transition.kill()
	for node in screen.get_children():
		screen.remove_child(node)
		node.queue_free()
	buttons.clear()
	stats = null
	dash_button = null
	special_button = null
	stick.reset()
	stick.enabled = game.mode == "playing"
	stick.blocked_rects.clear()
	screen.modulate.a = 1

func column(top: float, bottom: float, margin: int = 28) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.offset_left = margin
	node.offset_right = -margin
	node.anchor_top = top
	node.anchor_bottom = bottom
	node.offset_top = 0
	node.offset_bottom = 0
	node.add_theme_constant_override("separation", 10)
	screen.add_child(node)
	return node

func row() -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation", 12)
	return node

func spacer(parent: Control, height: int = 12) -> void:
	var node := Control.new()
	node.custom_minimum_size.y = height
	parent.add_child(node)

func body_text(text: String, size: int = 18, color: Color = MUTED) -> Label:
	var node := label(text, size, color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node

func home() -> void:
	clear("home")
	_veil(0,.17,.75,0)
	_veil(.52,1,.20,.98)
	var top:=column(.035,.14)
	var header:=row()
	top.add_child(header)
	var title:=label("RING RUSH",46,PAPER,true)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(label(str(int(MobileCore.save.data.coins)),24,AMBER,true))
	var options_button:=button("",settings,false,"gear")
	options_button.custom_minimum_size=Vector2(50,50)
	header.add_child(options_button)
	var name_plate:=column(.59,.66)
	var fighter_name:=label(game.selected_character().name,34,PAPER,true)
	fighter_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	name_plate.add_child(fighter_name)
	var loadout:=label(RushRoster.visual(game.selected_move()).short,16,RushRoster.visual(game.selected_move()).color)
	loadout.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	name_plate.add_child(loadout)
	var bottom:=column(.69,.92)
	var challenge:=button(RushWaveDirector.mode_info(game.run_mode).name+"  /  CHANGE",circuits,false,"crown")
	challenge.custom_minimum_size.y=48
	challenge.add_theme_font_size_override("font_size",21)
	bottom.add_child(challenge)
	var play:=button("RESUME FIGHT" if game.has_resume() else "PLAY",game.resume_saved_run if game.has_resume() else game.start_run,true,"play")
	play.custom_minimum_size.y=66
	play.add_theme_font_size_override("font_size",30)
	bottom.add_child(play)
	var nav:=row()
	bottom.add_child(nav)
	for entry in [["FIGHTER",fighters,"fist"],["SKILLS",moves,"bolt"],["SHOP",shop,"coin"]]:
		var b:=button(entry[0],entry[1],false,entry[2])
		b.add_theme_font_size_override("font_size",19)
		b.custom_minimum_size.y=54
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		nav.add_child(b)
	MobileCore.commerce.provider.set_banner(not game.ads_removed())

func showroom_header(title: String) -> void:
	var top:=column(.035,.14)
	var header:=row()
	top.add_child(header)
	var back:=button("",game.go_home,false,"back")
	back.custom_minimum_size=Vector2(52,52)
	header.add_child(back)
	var text:=label(title,34,PAPER,true)
	text.clip_text=true
	text.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	header.add_child(text)
	header.add_child(label(str(int(MobileCore.save.data.coins)),23,AMBER,true))

func cycle_fighter(direction: int) -> void:
	fighter_index=posmod(fighter_index+direction,RushRoster.CHARACTERS.size())
	fighters(true)

func attribute_line(parent: Control, title: String, value: float, maximum: float, text: String, color: Color) -> void:
	var line:=row()
	parent.add_child(line)
	var name:=label(title,14,MUTED)
	name.custom_minimum_size.x=68
	line.add_child(name)
	var meter:=bar(color,7)
	meter.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	meter.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	meter.value=value/maximum*100
	line.add_child(meter)
	var number:=label(text,15,PAPER)
	number.custom_minimum_size.x=42
	number.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(number)

func bar(color: Color, height: int = 9) -> ProgressBar:
	var node := ProgressBar.new()
	node.custom_minimum_size.y = height
	node.show_percentage = false
	var bg := style(Color("263449"),4)
	bg.content_margin_top = 0
	bg.content_margin_bottom = 0
	node.add_theme_stylebox_override("background",bg)
	var fill := bg.duplicate()
	fill.bg_color = color
	node.add_theme_stylebox_override("fill",fill)
	return node

func playing() -> void:
	clear("playing")
	_veil(0,.25,.90,0)
	_veil(.73,1,0,.67)
	var top:=column(.035,.17)
	var header:=row()
	top.add_child(header)
	stats=label("",26,PAPER,true)
	stats.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	header.add_child(stats)
	var pause:=button("",game.pause_run,false,"pause")
	pause.custom_minimum_size=Vector2(52,48)
	header.add_child(pause)
	var line:=row()
	top.add_child(line)
	hp_text=label("",14,TEAL)
	hp_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	line.add_child(hp_text)
	combo_text=label("",16,AMBER,true)
	line.add_child(combo_text)
	health_bar=bar(TEAL,9)
	top.add_child(health_bar)
	xp_bar=bar(AMBER,4)
	top.add_child(xp_bar)
	boss_title=label("",17,Color("f591a9"),true)
	top.add_child(boss_title)
	boss_bar=bar(Color("f591a9"),5)
	top.add_child(boss_bar)
	var actions:=Control.new()
	actions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	actions.offset_left=-222
	actions.offset_top=-270
	actions.offset_right=-12
	actions.offset_bottom=-15
	actions.mouse_filter=Control.MOUSE_FILTER_IGNORE
	screen.add_child(actions)
	var visual:=RushRoster.visual(game.technique_id)
	special_button=RushActionButton.new()
	special_button.setup("crown",AMBER,"ULTIMATE",94,game.special)
	special_button.position=Vector2(110,0)
	actions.add_child(special_button)
	technique_button=RushActionButton.new()
	technique_button.setup(visual.icon,visual.color,visual.short,88,game.technique)
	technique_button.position=Vector2(116,132)
	actions.add_child(technique_button)
	dash_button=RushActionButton.new()
	dash_button.setup("dash",Color("d5e5e3"),"DODGE",72,game.dash)
	dash_button.position=Vector2(12,160)
	actions.add_child(dash_button)
	buttons.append_array([dash_button,technique_button,special_button])
	hint=label("",14,MUTED)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_left=-160
	hint.offset_right=160
	hint.offset_top=-38
	hint.offset_bottom=-12
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	screen.add_child(hint)
	update_stats()
	call_deferred("_block_actions")

func _block_actions() -> void:
	if current_page != "playing": return
	stick.blocked_rects.clear()
	for b in buttons:
		if is_instance_valid(b): stick.blocked_rects.append(b.get_global_rect())

func update_stats() -> void:
	if not is_instance_valid(stats): return
	stats.text = "%02d:%02d    WAVE %d    %d KO" % [int(game.remaining)/60,int(game.remaining)%60,game.wave,game.kills] if game.run_mode == "classic" else "WAVE %d / %d    %d KO" % [game.wave,game.director.target,game.kills]
	hp_text.text = "HEALTH  %d / %d     LEVEL %d" % [ceili(game.hp),int(game.max_hp),game.level]
	combo_text.text = "%d COMBO" % game.combo if game.combo > 1 else ""
	health_bar.value = clampf(game.hp/game.max_hp*100,0,100)
	xp_bar.value = clampf(float(game.xp)/game.xp_needed*100,0,100)
	var boss_alive: bool = game.boss != null and game.boss.active
	boss_title.visible = boss_alive
	boss_bar.visible = boss_alive
	if boss_alive:
		boss_title.text = RushBalance.STAGES[game.stage].boss + ("  /  OVERTIME" if game.run_mode == "classic" and game.remaining <= 0 else "")
		boss_bar.value = game.boss.health / game.boss.max_health * 100
	dash_button.disabled=game.dash_clock>0
	dash_button.meter=1-game.dash_clock/maxf(.1,3.8-game.rank_of("dash")*.6)
	dash_button.value="%.1f"%game.dash_clock if game.dash_clock>0 else ""
	technique_button.disabled=game.technique_clock>0
	technique_button.meter=1-game.technique_clock/RushRoster.move(game.technique_id).cooldown
	technique_button.value="%.1f"%game.technique_clock if game.technique_clock>0 else ""
	special_button.disabled=game.special_charge<100
	special_button.meter=game.special_charge/100
	special_button.value="%d%%"%game.special_charge if game.special_charge<100 else ""
	hint.text="NEXT WAVE IN %.1f"%maxf(0,game.director.rest) if game.run_mode!="classic" and game.director.clearing else ("SPACE   /   Q   /   E" if not touch_device else "")

func page(title: String, detail: String, page_name: String, back: Callable = Callable()) -> VBoxContainer:
	clear(page_name)
	var shade := RushMenuBackdrop.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(shade)
	var top := column(0.055,0.18)
	var heading := row()
	top.add_child(heading)
	if back.is_valid():
		var b := button("",back,false,"back")
		b.custom_minimum_size = Vector2(52,52)
		heading.add_child(b)
	heading.add_child(label(title,44,PAPER,true))
	top.add_child(body_text(detail,17))
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.anchor_top = 0.205
	scroll.anchor_bottom = 0.935
	scroll.offset_left = 28
	scroll.offset_right = -28
	scroll.offset_top = 0
	scroll.offset_bottom = 0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	screen.add_child(scroll)
	page_body = VBoxContainer.new()
	page_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_body.add_theme_constant_override("separation",14)
	scroll.add_child(page_body)
	return page_body

func ability_card(entry: Dictionary, action: Callable, choice: bool) -> Button:
	var b := button("",action)
	b.custom_minimum_size.y = 120
	var layout := HBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 18
	layout.offset_right = -16
	layout.offset_top = 14
	layout.offset_bottom = -14
	layout.add_theme_constant_override("separation",18)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(layout)
	var skill_color:Color={"FIRE":Color("f3ba72"),"ICE":Color("9ccde9"),"LIGHTNING":Color("8cbfff"),"RECOVERY":Color("8dd6a8"),"DEFENSE":Color("b4b3de"),"POWER":Color("edaa72"),"TEMPO":Color("e9cb77"),"SUSTAIN":Color("8dd6a8"),"MOBILITY":Color("98c7ed"),"PRECISION":Color("efa58c"),"SPECIAL":Color("efc576"),"CONTROL":Color("c3b4ed"),"UTILITY":Color("c4d48d")}.get(entry.tag,TEAL)
	var symbol := icon(entry.icon,skill_color,40)
	symbol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	layout.add_child(symbol)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(text)
	var rank: int = game.rank_of(entry.id)
	text.add_child(label(entry.title.to_upper(),27,PAPER,true))
	var description := body_text(entry.detail,16,MUTED)
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(description)
	text.add_child(label(entry.tag + ("    RANK %d → %d" % [rank,rank+1] if choice else "    %d / %d" % [rank,entry.max]),12,skill_color))
	for child in text.get_children(): child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

func abilities(options: Array) -> void:
	if current_page not in ["playing","upgrade"]:playing()
	_remove_upgrade()
	current_page="upgrade"
	stick.enabled=false
	stick.reset()
	upgrade_overlay=Control.new()
	upgrade_overlay.name="UpgradePopup"
	upgrade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(upgrade_overlay)
	var scrim:=ColorRect.new()
	scrim.color=Color(0.02,.04,.07,.42)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	upgrade_overlay.add_child(scrim)
	upgrade_panel=PanelContainer.new()
	upgrade_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var width:=minf(490,root.size.x-36)
	upgrade_panel.offset_left=-width*.5
	upgrade_panel.offset_right=width*.5
	upgrade_panel.offset_top=-285
	upgrade_panel.offset_bottom=285
	var panel_style:=style(Color("142735"),18)
	panel_style.shadow_color=Color(0,0,0,.32)
	panel_style.shadow_size=16
	panel_style.shadow_offset=Vector2(0,8)
	upgrade_panel.add_theme_stylebox_override("panel",panel_style)
	upgrade_overlay.add_child(upgrade_panel)
	var col:=VBoxContainer.new()
	col.add_theme_constant_override("separation",10)
	upgrade_panel.add_child(col)
	col.add_child(label("CHOOSE YOUR EDGE",35,PAPER,true))
	col.add_child(label("LEVEL %d  ·  FIGHT PAUSED"%game.level,14,TEAL))
	for entry in options:
		var choice:=ability_card(entry,func():game.choose_ability(entry.id),true)
		choice.custom_minimum_size.y=110
		col.add_child(choice)
	var reroll_button:=button("REROLL  /  %d LEFT"%game.rerolls,game.reroll,false,"orbit")
	reroll_button.custom_minimum_size.y=50
	reroll_button.disabled=game.rerolls<=0
	col.add_child(reroll_button)
	_animate_upgrade()

func _motion_enabled() -> bool:
	return DisplayServer.get_name()!="headless" and not MobileCore.save.data.settings.get("reduced_motion",false)

func _animate_upgrade() -> void:
	if not _motion_enabled():return
	var panel:=upgrade_panel
	await get_tree().process_frame
	if not is_instance_valid(panel) or panel!=upgrade_panel:return
	panel.pivot_offset=panel.size*.5
	panel.scale=Vector2.ONE*.96
	panel.modulate.a=.65
	upgrade_tween=create_tween().set_parallel(true)
	upgrade_tween.tween_property(panel,"scale",Vector2.ONE,.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	upgrade_tween.tween_property(panel,"modulate:a",1.0,.16)

func close_upgrade() -> void:
	if upgrade_closing:return
	upgrade_closing=true
	if not _motion_enabled() or not is_instance_valid(upgrade_overlay):
		game.resume_run()
		return
	if upgrade_tween!=null:upgrade_tween.kill()
	upgrade_tween=create_tween()
	upgrade_tween.tween_property(upgrade_overlay,"modulate:a",0.0,.12)
	upgrade_tween.tween_callback(game.resume_run)

func _remove_upgrade() -> void:
	if upgrade_tween!=null:upgrade_tween.kill()
	if is_instance_valid(upgrade_overlay):
		root.remove_child(upgrade_overlay)
		upgrade_overlay.queue_free()
	upgrade_overlay=null
	upgrade_panel=null
	upgrade_closing=false


func paused() -> void:
	var col := page("IN YOUR CORNER", "The clock is stopped. Your fight will wait.","paused")
	col.add_child(button("BACK TO THE FIGHT",game.resume_run,true,"fist"))
	col.add_child(button("VIEW YOUR BUILD",skills,false,"book"))
	col.add_child(button("SETTINGS",settings,false,"gear"))
	col.add_child(button("END RUN & BANK COINS",func():game.finish_run(false)))
	spacer(col,14)
	col.add_child(body_text("Move: left thumb or WASD / arrows\nDodge: Space · Skill: Q · Ultimate: E\nRed circles warn of incoming attacks.",18))

func result(won: bool, saved: bool) -> void:
	var col:=page("VICTORY" if won else "GOOD FIGHT",RushWaveDirector.mode_info(game.run_mode).name,"result")
	col.add_child(icon("crown" if won else "fist",AMBER,64))
	col.add_child(label("%d COINS"%game.run_coins,50,AMBER,true))
	col.add_child(label("%d WAVES   ·   %d KNOCKOUTS"%[game.completed_waves,game.kills],18,MUTED))
	spacer(col,22)
	if saved:
		if won:
			var claimed:bool=game.result_bonus_claimed()
			var extra:=button("BONUS CLAIMED" if claimed else "+%d COINS  /  WATCH AD"%ceili(game.run_coins*.5),game.request_victory_bonus,false,"ad")
			extra.disabled=claimed
			extra.set_meta("permanent_disabled",claimed)
			col.add_child(extra)
			col.add_child(body_text("Optional. Your victory reward is already saved.",15))
		spacer(col,16)
		col.add_child(button("PLAY AGAIN",game.replay_result,true,"play"))
		col.add_child(button("HOME",game.leave_result))
	else:
		col.add_child(body_text("Free some storage, then save your reward. It will only be paid once.",18))
		col.add_child(button("RETRY SAVE",func():game.finish_run(won),true))

func revive_offer() -> void:
	var col:=page("ONE MORE ROUND?","Your fight is paused. Choose whether to continue.","defeat")
	col.add_child(icon("heart",Color("91d8b3"),72))
	col.add_child(label("WAVE %d"%game.wave,46,PAPER,true))
	col.add_child(body_text("Return with 60% health and 3 seconds of protection.",22,PAPER))
	col.add_child(label("ONE REVIVE PER FIGHT",14,MUTED))
	spacer(col,24)
	col.add_child(button("REVIVE  /  WATCH AD",game.request_revive,true,"ad"))
	col.add_child(button("END FIGHT & KEEP %d COINS"%game.run_coins,func():game.finish_run(false)))
	col.add_child(body_text("Watching is optional. Closing early gives no extra life.",15))

func move_demo(id:String) -> void:
	clear("move_demo")
	showroom_header("TRY A SKILL")
	var visual:=RushRoster.visual(id)
	var bottom:=column(.70,.96)
	bottom.add_child(label(visual.short,34,visual.color,true))
	bottom.add_child(body_text(visual.hint,18,PAPER))
	bottom.add_child(button("PLAY EFFECT AGAIN",func():game.demo_move(id),true,"play"))
	bottom.add_child(button("BACK TO SKILLS",func():game._clear_combat();moves(true)))

func circuits(keep_index:bool=false) -> void:
	if not keep_index:venue_index=game.stage
	clear("circuits")
	game.preview_venue(venue_index)
	_veil(0,.18,.90,0)
	showroom_header("CHOOSE A FIGHT")
	# The real 3D venue is above its controls. An opaque lower deck stays still.
	var deck:=RushMenuBackdrop.new()
	deck.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	deck.anchor_top=.49
	deck.offset_top=0
	screen.add_child(deck)
	var col:=column(.51,.98)
	col.add_theme_constant_override("separation",9)
	var select:=row()
	col.add_child(select)
	var left:=button("",func():cycle_venue(-1),false,"back")
	left.custom_minimum_size.x=52
	select.add_child(left)
	var name:=label(RushBalance.STAGES[venue_index].name,28,PAPER,true)
	name.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	select.add_child(name)
	var right:=button("",func():cycle_venue(1),false,"right")
	right.custom_minimum_size.x=52
	select.add_child(right)
	left.disabled=game.run_mode=="ladder"
	right.disabled=game.run_mode=="ladder"
	var unlocked:bool=venue_index<=int(MobileCore.save.data.progress.get("unlocked_stage",0))
	col.add_child(body_text("All five venues · Automatic progression" if game.run_mode=="ladder" else (RushBalance.STAGES[venue_index].detail if unlocked else "LOCKED · Win the previous venue to enter."),16,TEAL if unlocked else AMBER))
	var grid:=GridContainer.new()
	grid.columns=2
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",8)
	col.add_child(grid)
	for mode in RushWaveDirector.MODES:
		var b:=button(mode.name,func():select_challenge(mode.id),game.run_mode==mode.id)
		b.add_theme_font_size_override("font_size",20)
		b.custom_minimum_size.y=48
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		grid.add_child(b)
	col.add_child(body_text(RushWaveDirector.mode_info(game.run_mode).detail,15))
	if game.has_resume():
		var saved:=row()
		col.add_child(saved)
		for entry in [["RESUME FIGHT",game.resume_saved_run],["BANK SAVED FIGHT",game.bank_saved_run]]:
			var b:=button(entry[0],entry[1],entry[0]=="RESUME FIGHT")
			b.custom_minimum_size.y=54
			b.add_theme_font_size_override("font_size",20)
			b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			saved.add_child(b)
	else:
		var done:=button("USE THIS FIGHT" if unlocked else "VENUE LOCKED",func():game.stage=venue_index;game.go_home(),true,"play")
		done.custom_minimum_size.y=54
		done.disabled=not unlocked
		col.add_child(done)

func select_challenge(id:String) -> void:
	game.run_mode=id
	if id=="ladder":venue_index=0
	circuits(true)

func cycle_venue(direction:int) -> void:
	venue_index=posmod(venue_index+direction,5)
	circuits(true)

func fighters(keep_index: bool=false) -> void:
	if not keep_index:
		for i in RushRoster.CHARACTERS.size():
			if RushRoster.CHARACTERS[i].id==game.selected_character().id:fighter_index=i
	clear("fighters")
	var fighter: Dictionary=RushRoster.CHARACTERS[fighter_index]
	game.preview_character(fighter.id)
	_veil(0,.17,.75,0)
	_veil(.53,1,.28,.98)
	showroom_header("FIGHTERS")
	var gesture:=column(.55,.58)
	var tip:=label("DRAG TO ROTATE  /  ARROWS SWITCH",13,MUTED)
	tip.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	gesture.add_child(tip)
	for side in [-1,1]:
		var arrow:=button("",func():cycle_fighter(side),false,"back" if side<0 else "right")
		arrow.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT if side<0 else Control.PRESET_CENTER_RIGHT)
		arrow.anchor_top=.38
		arrow.anchor_bottom=.38
		arrow.offset_top=-28
		arrow.offset_bottom=28
		arrow.offset_left=22 if side<0 else -78
		arrow.offset_right=78 if side<0 else -22
		screen.add_child(arrow)
	var info:=column(.59,.88)
	var heading:=row()
	info.add_child(heading)
	var name:=label(fighter.name,38,PAPER,true)
	name.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	heading.add_child(name)
	heading.add_child(label("%d / %d"%[fighter_index+1,RushRoster.CHARACTERS.size()],17,MUTED))
	attribute_line(info,"POWER",fighter.damage,30,str(int(fighter.damage)),fighter.color)
	attribute_line(info,"HEALTH",fighter.hp,160,str(int(fighter.hp)),fighter.color)
	attribute_line(info,"SPEED",fighter.speed,6,"%.1f"%fighter.speed,fighter.color)
	var visual:=RushRoster.visual(fighter.move)
	var move_line:=row()
	info.add_child(move_line)
	move_line.add_child(icon(visual.icon,visual.color,30))
	move_line.add_child(label(visual.short+"  ·  "+visual.tag,18,visual.color,true))
	info.add_child(body_text(fighter.passive,15))
	var owned:=RushRoster.owned(MobileCore.save,"character",fighter.id)
	var selected:bool=game.selected_character().id==fighter.id
	var bottom:=column(.90,.98)
	var select:=button("SELECTED" if selected else ("USE FIGHTER" if owned else "UNLOCK  /  %d COINS"%fighter.price),func():
		if not RushRoster.unlock(MobileCore.save,"character",fighter.id):toast("Not enough coins, or storage is unavailable.");return
		if not RushRoster.equip(MobileCore.save,"character",fighter.id):toast("Selection could not be saved.");return
		fighters(true),not selected,"fist")
	select.disabled=selected or (not owned and MobileCore.save.data.coins<fighter.price)
	bottom.add_child(select)

func moves(keep_index: bool=false) -> void:
	if not keep_index:
		for i in RushRoster.MOVES.size():
			if RushRoster.MOVES[i].id==game.selected_move():move_index=i
	clear("moves")
	game.preview_character(game.selected_character().id)
	game.player.visible=false
	game.podium.visible=false
	var backdrop:=RushMenuBackdrop.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(backdrop)
	showroom_header("SKILLS")
	var selected: Dictionary=RushRoster.MOVES[move_index]
	var visual:=RushRoster.visual(selected.id)
	var grid:=GridContainer.new()
	grid.columns=3
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid.anchor_top=.16
	grid.anchor_bottom=.47
	grid.offset_left=24
	grid.offset_right=-24
	grid.offset_top=0
	grid.offset_bottom=0
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",10)
	screen.add_child(grid)
	for i in RushRoster.MOVES.size():
		var move: Dictionary=RushRoster.MOVES[i]
		var look:=RushRoster.visual(move.id)
		var tile:=button("",func():move_index=i;moves(true))
		tile.custom_minimum_size=Vector2(0,126)
		tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var bg:=style(Color("203541") if i==move_index else Color("101e2b"),12)
		if i==move_index:bg.set_border_width_all(2);bg.border_color=look.color
		tile.add_theme_stylebox_override("normal",bg)
		var symbol:=icon(look.icon,look.color,44)
		symbol.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		symbol.offset_left=-22
		symbol.offset_right=22
		symbol.offset_top=15
		symbol.offset_bottom=59
		tile.add_child(symbol)
		var text:=label(look.short,19,PAPER,true)
		text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		text.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		text.offset_top=-51
		text.offset_bottom=-26
		tile.add_child(text)
		var state:=label("EQUIPPED" if game.selected_move()==move.id else ("OWNED" if RushRoster.owned(MobileCore.save,"move",move.id) else "%d COINS"%move.price),11,look.color)
		state.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		state.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		state.offset_top=-25
		state.offset_bottom=-8
		tile.add_child(state)
		grid.add_child(tile)
	var detail:=column(.52,.72)
	detail.add_child(label(visual.short,34,visual.color,true))
	detail.add_child(body_text(visual.hint,19,PAPER))
	detail.add_child(label(visual.tag+"   ·   %.1f s"%selected.cooldown,14,visual.color))
	var bottom:=column(.77,.97)
	bottom.add_child(button("TRY EFFECT",func():game.demo_move(selected.id),false,"play"))
	var owned:=RushRoster.owned(MobileCore.save,"move",selected.id)
	var equipped:bool=game.selected_move()==selected.id
	var equip:=button("EQUIPPED" if equipped else ("EQUIP SKILL" if owned else "UNLOCK / %d COINS"%selected.price),func():
		if not RushRoster.unlock(MobileCore.save,"move",selected.id):toast("Not enough coins, or storage is unavailable.");return
		if not RushRoster.equip(MobileCore.save,"move",selected.id):toast("Selection could not be saved.");return
		game.technique_id=selected.id
		moves(true),not equipped,visual.icon)
	equip.disabled=equipped or (not owned and MobileCore.save.data.coins<selected.price)
	bottom.add_child(equip)
	var book:=button("PASSIVE UPGRADES",skills,false,"book")
	book.custom_minimum_size.y=46
	book.add_theme_font_size_override("font_size",18)
	bottom.add_child(book)

func training() -> void:
	var col := page("THE GYM", "Permanent training. Your balance: %d coins." % MobileCore.save.data.coins,"training",home)
	col.add_child(button("PASSIVE SKILL PLAYBOOK",skills,false,"book"))
	col.add_child(button("COSMETIC STORE",shop,false,"crown"))
	for entry in RushBalance.TRAINING:
		var level := clampi(int(MobileCore.save.data.progress.get(entry.id,0)),0,5)
		var cost := RushBalance.training_cost(level)
		col.add_child(label(entry.title.to_upper()+"    %d / 5"%level,29,PAPER,true))
		col.add_child(body_text(entry.detail,17))
		var b := button("MAXIMUM TRAINING" if level>=5 else "TRAIN  /  %d COINS"%cost,func():
			if MobileCore.save.buy_upgrade(entry.id,cost): training()
			else: toast("Could not save training. Check your balance and free storage."),level<5,entry.icon)
		b.disabled = level>=5 or MobileCore.save.data.coins<cost
		col.add_child(b)
		spacer(col,12)

func skills() -> void:
	var in_run: bool = game.mode == "paused"
	var col := page("YOUR BUILD" if in_run else "THE PLAYBOOK", "18 stackable skills. Combine them with your signature technique. Find your fighting style.","skills",paused if in_run else home)
	if in_run:
		col.add_child(body_text("Damage %.0f   ·   Reach %.1fm   ·   Punch every %.2fs" % [game.damage,game.reach,game.cooldown],17,TEAL))
	col.add_child(label("ACTIVE MOVES",28,PAPER,true))
	col.add_child(body_text("DASH / SPACE — slip through danger with brief invulnerability.\nTECHNIQUE / Q — your equipped move, recharging on a cooldown.\nULTIMATE / E — an amplified version, charged with knockouts.",17))
	spacer(col)
	for entry in RushBalance.ABILITIES:
		if in_run and game.rank_of(entry.id)==0: continue
		var card := ability_card(entry,Callable(),false)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.focus_mode = Control.FOCUS_NONE
		col.add_child(card)
	if in_run and game.ranks.is_empty(): col.add_child(body_text("No skills yet. Collect teal experience gems to level up.",18))

func shop() -> void:
	var test:bool=MobileCore.commerce.provider.is_mock
	var owned:bool=game.ads_removed()
	var col:=page("SHOP","Development store. Test purchases never charge money." if test else "Permanent upgrades and optional rewards.","shop",game.go_home)
	col.add_child(icon("shield",AMBER,58))
	col.add_child(label("REMOVE ADS",38,PAPER,true))
	col.add_child(body_text("One permanent unlock. No banners or automatic ad breaks.",20,PAPER))
	col.add_child(body_text("Optional reward videos stay available for revives and extra coins.",16))
	var buy:=button("OWNED" if owned else ("TEST PURCHASE  /  NO CHARGE" if test else "STORE UNAVAILABLE"),func():MobileCore.commerce.buy("remove_ads"),not owned,"shield")
	buy.disabled=owned or not test
	buy.set_meta("permanent_disabled",buy.disabled)
	col.add_child(buy)
	spacer(col,16)
	col.add_child(button("TRAINING",training,false,"fist"))
	col.add_child(button("GOLD GLOVES & COIN REWARDS",cosmetics,false,"coin"))
	col.add_child(button("RESTORE PURCHASES",func():MobileCore.commerce.restore()))
	_busy(not MobileCore.commerce.pending.is_empty())

func cosmetics() -> void:
	var test: bool = MobileCore.commerce.provider.is_mock
	var owned: bool = MobileCore.save.data.entitlements.get("gold_gloves",false)
	var col := page("THE LOCKER", "Development store · No real ads or charges." if test else "The native store is not connected in this build.","cosmetics",shop)
	col.add_child(label("GOLD GLOVES",38,AMBER,true))
	col.add_child(body_text("A champion's finish. Purely cosmetic; your fists do the work.",18))
	col.add_child(button("EQUIPPED" if owned else "TEST UNLOCK",func():MobileCore.commerce.buy("gold_gloves"),true,"fist"))
	buttons[-1].set_meta("permanent_disabled",owned or not test)
	buttons[-1].disabled = owned or not test
	spacer(col,14)
	col.add_child(label("EXTRA TRAINING",30,PAPER,true))
	col.add_child(body_text("Complete a simulated rewarded ad to receive 60 training coins.",18))
	col.add_child(button("TEST AD  /  +60 COINS",func():MobileCore.commerce.reward("training_coins"),false,"coin"))
	buttons[-1].set_meta("permanent_disabled",not test)
	col.add_child(button("RESTORE PURCHASES",func():MobileCore.commerce.restore()))
	_busy(not MobileCore.commerce.pending.is_empty())

func settings() -> void:
	var col := page("MAKE IT YOURS", "Tune the experience for your device.","settings",paused if game.mode=="paused" else home)
	for entry in [["effects","IMPACT EFFECTS"],["haptics","HAPTIC FEEDBACK"],["sound","SOUND EFFECTS"],["music","MUSIC"],["low_quality","BATTERY SAVER"]]:
		var key: String = entry[0]
		var enabled: bool = MobileCore.save.data.settings.get(key,key!="low_quality")
		col.add_child(button(entry[1]+"  /  "+("ON" if enabled else "OFF"),func():
			if MobileCore.save.set_setting(key,not enabled):
				game.apply_settings()
				settings()
			else: toast("Could not save settings. Free storage and try again.")))
	var reduced:=button("REDUCED MOTION: " + ("ON" if MobileCore.save.data.settings.get("reduced_motion",false) else "OFF"),func():MobileCore.save.set_setting("reduced_motion",not MobileCore.save.data.settings.get("reduced_motion",false));settings())
	col.add_child(reduced)
	col.add_child(body_text("Battery saver disables real-time shadows, the audience and anti-aliasing. Gameplay and skill effects are unchanged.",16))
	spacer(col)
	col.add_child(body_text("Touch: drag to move; use dodge, technique and ultimate.\nKeyboard: WASD / arrows, Space to dodge, Q for technique, E for ultimate, Esc to pause.\nRuns pause when the app loses focus.",17))

func _commerce_completed(_success: bool,text: String) -> void:
	game.player.set_gold(MobileCore.save.data.entitlements.get("gold_gloves",false))
	if current_page == "shop": shop()
	elif current_page == "cosmetics":cosmetics()
	elif current_page == "defeat":revive_offer()
	elif current_page == "result":result(game.result_won,MobileCore.save.data.transactions.has(game.run_id))
	elif current_page == "home": home()
	toast(text)

func _busy(value: bool) -> void:
	for b in buttons:
		if is_instance_valid(b): b.disabled = value or b.get_meta("permanent_disabled",false)
	if value: toast("Test provider running…" if MobileCore.commerce.provider.is_mock else "Connecting…")

func toast(text: String) -> void:
	message.text = text
	message.visible = true
	toast_time = 4

func flash_damage() -> void:
	if not is_instance_valid(health_bar) or not game.vfx.enabled:return
	health_bar.self_modulate=Color("ff766e")
	create_tween().tween_property(health_bar,"self_modulate",Color.WHITE,.24)

func _veil(top:float,bottom:float,start_alpha:float,end_alpha:float) -> void:
	var gradient:=Gradient.new()
	gradient.set_color(0,Color(INK,start_alpha))
	gradient.set_color(1,Color(INK,end_alpha))
	var texture:=GradientTexture2D.new()
	texture.gradient=gradient
	texture.width=4
	texture.height=128
	texture.fill_from=Vector2.ZERO
	texture.fill_to=Vector2(0,1)
	var veil:=TextureRect.new()
	veil.texture=texture
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.anchor_top=top
	veil.anchor_bottom=bottom
	veil.mouse_filter=Control.MOUSE_FILTER_IGNORE
	screen.add_child(veil)
