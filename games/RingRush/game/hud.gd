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
var boss_cue:Label
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
var gym_filter:="ALL"
var badge_filter:="ALL"
var equipment_filter:="ALL"
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
var upgrade_scroll:ScrollContainer
var upgrade_choices:VBoxContainer
var toast_tween:Tween

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
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	message.anchor_top=.14
	message.anchor_bottom=.14
	message.offset_left = 24
	message.offset_right = -24
	message.offset_top = 0
	message.offset_bottom = 64
	message.mouse_filter=Control.MOUSE_FILTER_IGNORE
	message.add_theme_stylebox_override("normal", style(Color("147b72"), 12))
	message.visible = false
	root.add_child(message)
	MobileCore.notices.posted.connect(_present_notice)
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
	if not MobileCore.commerce.pending.is_empty():return
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
	var node := RushContentButton.new() if text.is_empty() and glyph.is_empty() else Button.new()
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
		symbol.size = Vector2(32,32)
		CoreButtonLayout.install(node,symbol)
		node.set_meta("glyph",symbol)
		node.set_meta("glyph_tint",symbol.tint)
	if action.is_valid(): node.pressed.connect(action)
	buttons.append(node)
	return node

func _place_glyph(b,symbol) -> void:
	CoreButtonLayout.place(b,symbol)

func clear(page_name: String = "") -> void:
	_remove_upgrade()
	rotation_finger=-1
	mouse_rotating=false
	toast_time=0
	message.visible=false
	game.player.visible=page_name in ["home","fighters","move_demo","playing"]
	game.podium.visible=game.mode=="home" and page_name in ["home","fighters"]
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
	var dock:=column(1,1)
	dock.offset_top=-394 if not game.ads_removed() else -350
	dock.offset_bottom=-64 if not game.ads_removed() else -20
	dock.add_theme_constant_override("separation",16)
	var identity:=row();identity.name="FighterIdentity";dock.add_child(identity)
	var who:=VBoxContainer.new();who.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	identity.add_child(who)
	who.add_child(label(game.selected_character().name,40,PAPER,true))
	who.add_child(label(game.selected_character().style,13,MUTED))
	var move:=RushRoster.visual(game.selected_move())
	var signature:=row();signature.alignment=BoxContainer.ALIGNMENT_END
	signature.size_flags_vertical=Control.SIZE_SHRINK_CENTER;identity.add_child(signature)
	signature.add_child(icon(move.icon,move.color,30))
	signature.add_child(label(move.short,19,move.color,true))
	var nav:=HBoxContainer.new();nav.name="SideNavigation"
	nav.add_theme_constant_override("separation",10);dock.add_child(nav)
	for entry in [["FIGHTER",fighters,"fist",Color("68ead1"),Color("163d40")],["SKILLS",moves,"bolt",Color("c9a6ff"),Color("342847")],["GYM",training,"dumbbell",Color("ffad87"),Color("4a302e")],["SHOP",shop,"coin",Color("ffdb7b"),Color("443b25")]]:
		var b:=button("",entry[1],false,entry[2]);b.name=entry[0]
		b.custom_minimum_size=Vector2(0,78);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		b.set_meta("nav_tile",true);b.set_meta("glyph_tint",entry[3])
		for state in ["normal","hover","pressed"]:
			var surface:=style(entry[4].lightened(.12) if state=="hover" else entry[4],12)
			b.add_theme_stylebox_override(state,surface)
		var caption:=label(entry[0],17,PAPER,true)
		caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		caption.offset_top=-30;caption.offset_bottom=-8;caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
		b.add_child(caption);nav.add_child(b)
	var growth_nav:=row();growth_nav.name="HomeGrowthNavigation";dock.add_child(growth_nav)
	for entry in [["COMPANIONS",equipment,"orbit",Color("1f4350"),"HomeEquipment"],["BADGES",achievements,"crown",Color("433743"),"HomeBadges"]]:
		var b:=button(entry[0],entry[1],false,entry[2]);b.name=entry[4]
		b.custom_minimum_size.y=48;b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.add_theme_font_size_override("font_size",20)
		for state in ["normal","hover","pressed"]:b.add_theme_stylebox_override(state,style(entry[3].lightened(.12) if state=="hover" else entry[3],12))
		growth_nav.add_child(b)
	var play:=button("RESUME FIGHT" if game.has_resume() else "PLAY",game.resume_saved_run if game.has_resume() else circuits,true,"play")
	play.name="HomePlay";play.custom_minimum_size.y=66;play.add_theme_font_size_override("font_size",30)
	dock.add_child(play)
	MobileCore.commerce.provider.set_banner(not game.ads_removed())

func showroom_header(title: String,back_action:Callable=Callable()) -> void:
	var top:=column(.035,.14)
	var header:=row()
	top.add_child(header)
	var back:=button("",back_action if back_action.is_valid() else game.go_home,false,"back")
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
	boss_cue=label("",16,AMBER,true)
	var cue_style:=style(Color("101f30"),8)
	cue_style.content_margin_top=5
	cue_style.content_margin_bottom=5
	boss_cue.add_theme_stylebox_override("normal",cue_style)
	boss_cue.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(boss_cue)
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
	special_button.setup("crown",AMBER,{"rupture":"BREAKER","storm":"SKYFALL","siege":"SIEGE"}[RushUltimates.kind(game.player.character_id)],94,game.special)
	special_button.tooltip_text=RushUltimates.description(game.player.character_id)
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
	boss_cue.visible = boss_alive
	if boss_alive:
		boss_title.text = RushBalance.STAGES[game.stage].boss + ("  /  II" if game.boss.encounter.phase==2 else "  /  I") + ("  /  OVERTIME" if game.run_mode == "classic" and game.remaining <= 0 else "")
		boss_bar.value = game.boss.health / game.boss.max_health * 100
		boss_cue.text=game.boss.encounter.caption()
		boss_cue.add_theme_color_override("font_color",game.boss.encounter.tint())
	dash_button.disabled=game.dash_clock>0
	dash_button.meter=1-game.dash_clock/maxf(.1,3.8-game.rank_of("dash")*.6)
	dash_button.value="%.1f"%game.dash_clock if game.dash_clock>0 else ""
	technique_button.disabled=game.technique_clock>0
	technique_button.meter=1-game.technique_clock/game.technique_cooldown()
	technique_button.value="%.1f"%game.technique_clock if game.technique_clock>0 else ""
	technique_button.caption="BREAK!" if boss_alive and game.boss.encounter.breakable() and game.technique_clock<=0 else RushRoster.visual(game.technique_id).short
	technique_button.accent=RushBossCombat.BREAK if technique_button.caption=="BREAK!" else RushRoster.visual(game.technique_id).color
	technique_button.glyph.tint=technique_button.accent
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
	var b: RushContentButton = button("",action)
	b.name="Skill_"+entry.id
	var skill_color:Color={"RANGED":Color("88d6ff"),"FIRE":Color("ffad70"),"ICE":Color("8de5ff"),"LIGHTNING":Color("91c9ff"),"RECOVERY":Color("89ffb5"),"DEFENSE":Color("d0b6ff"),"POWER":Color("ffb877"),"TEMPO":Color("ffe27c"),"SUSTAIN":Color("89ffb5"),"MOBILITY":Color("a3e1ff"),"PRECISION":Color("ffabbb"),"SPECIAL":Color("ffe27c"),"CONTROL":Color("d9bcff"),"UTILITY":Color("cfef83")}.get(entry.tag,TEAL)
	skill_color={"echo_bolt":Color("82efff"),"frost_fan":Color("b5e4ff"),"seeker":Color("ffc788"),"ricochet":Color("d6adff"),"longshot":Color("b8ed98")}.get(entry.id,skill_color)
	for state in ["normal","hover","pressed"]:
		var surface:=style(Color("183e70").lerp(skill_color,.10 if state=="normal" else .20),14)
		surface.set_border_width_all(1)
		surface.border_color=skill_color.darkened(.45)
		surface.set_content_margin_all(0)
		b.add_theme_stylebox_override(state,surface)
	b.content=MarginContainer.new()
	b.content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]:b.content.add_theme_constant_override("margin_"+edge,16)
	b.content.mouse_filter=Control.MOUSE_FILTER_IGNORE
	b.add_child(b.content)
	var layout:=HBoxContainer.new()
	layout.add_theme_constant_override("separation",16)
	layout.mouse_filter=Control.MOUSE_FILTER_IGNORE
	b.content.add_child(layout)
	var symbol:=icon(entry.icon,skill_color,36)
	symbol.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	layout.add_child(symbol)
	var text:=VBoxContainer.new()
	text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation",4)
	text.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layout.add_child(text)
	var rank:int=game.rank_of(entry.id)
	var title:=label(entry.title.to_upper(),27,PAPER,true)
	title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	text.add_child(title)
	text.add_child(body_text(entry.detail,16,Color("d7e9ff")))
	var rank_label:=body_text(entry.tag+("    RANK %d > %d"%[rank,rank+1] if choice else "    %d / %d"%[rank,entry.max]),12,skill_color)
	rank_label.name="Rank"
	text.add_child(rank_label)
	for child in text.get_children():child.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return b

func abilities(options: Array) -> void:
	if current_page not in ["playing","upgrade"]:playing()
	_remove_upgrade()
	for b in buttons:
		if is_instance_valid(b):b.disabled=true
	current_page="upgrade"
	stick.enabled=false
	stick.reset()
	upgrade_overlay=Control.new()
	upgrade_overlay.name="UpgradePopup"
	upgrade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(upgrade_overlay)
	var scrim:=ColorRect.new()
	scrim.color=Color(.02,.04,.12,.52)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	upgrade_overlay.add_child(scrim)
	var center:=CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	upgrade_overlay.add_child(center)
	upgrade_panel=PanelContainer.new()
	var panel_style:=style(Color("163065"),20)
	panel_style.set_border_width_all(2)
	panel_style.border_color=Color("427fea")
	panel_style.content_margin_top=20
	panel_style.content_margin_bottom=20
	panel_style.shadow_color=Color(0,0,0,.32)
	panel_style.shadow_size=16
	panel_style.shadow_offset=Vector2(0,8)
	upgrade_panel.add_theme_stylebox_override("panel",panel_style)
	center.add_child(upgrade_panel)
	var col:=VBoxContainer.new()
	col.add_theme_constant_override("separation",12)
	upgrade_panel.add_child(col)
	col.add_child(label("CHOOSE YOUR EDGE",35,PAPER,true))
	col.add_child(label("LEVEL %d  ·  PICK A POWER-UP"%game.level,14,TEAL))
	upgrade_scroll=ScrollContainer.new()
	upgrade_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(upgrade_scroll)
	upgrade_choices=VBoxContainer.new()
	upgrade_choices.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	upgrade_choices.add_theme_constant_override("separation",10)
	upgrade_scroll.add_child(upgrade_choices)
	for entry in options:upgrade_choices.add_child(ability_card(entry,func():game.choose_ability(entry.id),true))
	var reroll_button:=button("SHUFFLE  ·  %d"%game.rerolls,game.reroll,false,"orbit")
	reroll_button.custom_minimum_size.y=50
	reroll_button.disabled=game.rerolls<=0
	for state in ["normal","hover","pressed"]:
		var shuffle_style:=style(Color("254981") if state=="normal" else Color("34619f"),14)
		shuffle_style.set_border_width_all(1);shuffle_style.border_color=Color("6391cd")
		reroll_button.add_theme_stylebox_override(state,shuffle_style)
	col.add_child(reroll_button)
	upgrade_choices.minimum_size_changed.connect(_fit_upgrade)
	upgrade_overlay.resized.connect(_fit_upgrade)
	_fit_upgrade()
	_animate_upgrade()

func _fit_upgrade() -> void:
	if not is_instance_valid(upgrade_panel):return
	var width:=minf(490,root.size.x-32)
	upgrade_panel.custom_minimum_size.x=width
	upgrade_scroll.custom_minimum_size=Vector2(width-40,minf(upgrade_choices.get_combined_minimum_size().y,maxf(120,root.size.y-224)))

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
		for b in buttons.duplicate():
			if not is_instance_valid(b) or upgrade_overlay.is_ancestor_of(b):buttons.erase(b)
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
	if saved and not MobileCore.save.data.progress.get("last_badges",[]).is_empty():
		col.add_child(button("%d NEW BADGES"%MobileCore.save.data.progress.last_badges.size(),achievements,false,"crown"))
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
	showroom_header("TRY A SKILL",func():moves(true))
	var visual:=RushRoster.visual(id)
	var bottom:=column(.70,.96)
	bottom.add_child(label(visual.short,34,visual.color,true))
	bottom.add_child(body_text(visual.hint,18,PAPER))
	bottom.add_child(button("PLAY EFFECT AGAIN",func():game.demo_move(id),true,"play"))
	bottom.add_child(button("BACK TO SKILLS",func():game._clear_combat();moves(true)))

func circuits(keep_index:bool=false) -> void:
	if not keep_index:venue_index=5 if game.run_mode=="rift" else (game.stage if game.stage in RushChallenges.ROUTE else 0)
	clear("circuits")
	game.preview_venue(venue_index)
	_veil(0,.18,.90,0)
	showroom_header("CHOOSE A FIGHT")
	var deck:=RushMenuBackdrop.new()
	deck.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	deck.anchor_top=.41;deck.offset_top=0
	screen.add_child(deck)
	var scroll:=ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.anchor_top=.43;scroll.offset_top=0;scroll.offset_bottom=-130
	scroll.offset_left=28;scroll.offset_right=-28
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	screen.add_child(scroll)
	var col:=VBoxContainer.new();col.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation",12);scroll.add_child(col)
	var select:=row();col.add_child(select)
	var left:=button("",func():cycle_venue(-1),false,"back")
	left.custom_minimum_size=Vector2(52,52);select.add_child(left)
	var name:=label(RushBalance.STAGES[venue_index].name,28,PAPER,true)
	name.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	name.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	select.add_child(name)
	var right:=button("",func():cycle_venue(1),false,"right")
	right.custom_minimum_size=Vector2(52,52);select.add_child(right)
	left.disabled=game.run_mode in ["ladder","rift"];right.disabled=left.disabled
	var family:=label(RushEncounterRoster.LABELS[venue_index],14,RushBalance.STAGES[venue_index].tint)
	family.name="VenueEnemies";family.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;col.add_child(family)
	var unlocked:bool=RushChallenges.available(MobileCore.save,game.run_mode,venue_index)
	var grid:=GridContainer.new();grid.columns=2
	grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",10)
	col.add_child(grid)
	for mode in RushWaveDirector.MODES:
		if mode.id=="rift":continue
		var b:=button(mode.name,func():select_challenge(mode.id),game.run_mode==mode.id,mode.icon)
		b.name="Mode_"+mode.id
		b.add_theme_font_size_override("font_size",20)
		b.custom_minimum_size.y=52;b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		grid.add_child(b)
	var secret:=button("THE RIFT" if RushChallenges.rift_open(MobileCore.save) else "SEALED ENCOUNTER",func():select_challenge("rift"),game.run_mode=="rift","skull" if RushChallenges.rift_open(MobileCore.save) else "lock")
	secret.name="SecretMode";secret.custom_minimum_size.y=46;secret.add_theme_font_size_override("font_size",20)
	col.add_child(secret)
	col.add_child(body_text("Clear %s to enter"%RushChallenges.previous_name(venue_index) if not unlocked and game.run_mode!="rift" else RushWaveDirector.mode_info(game.run_mode).detail+(" / CONTRACT +25%" if game.challenge_contract else ""),15))
	var footer:=column(1,1)
	footer.offset_top=-100;footer.offset_bottom=-28
	if not unlocked and game.run_mode!="rift" and not game.has_resume():
		footer.offset_top=-130
		var lock_hint:=label("CLEAR "+RushChallenges.previous_name(venue_index)+" TO UNLOCK",14,AMBER)
		lock_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;footer.add_child(lock_hint)
	if game.has_resume():
		var saved:=row();footer.add_child(saved)
		for entry in [["RESUME",game.resume_saved_run],["BANK & EXIT",game.bank_saved_run]]:
			var b:=button(entry[0],entry[1],entry[0]=="RESUME","play" if entry[0]=="RESUME" else "coin")
			b.add_theme_font_size_override("font_size",20);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			saved.add_child(b)
	else:
		var sealed:bool=game.run_mode=="rift" and not unlocked
		var done:=button("UNLOCK RIFT  /  %d COINS"%RushChallenges.SECRET_COST if sealed else ("FIGHT" if unlocked else "VENUE LOCKED"),func():
			if sealed:
				if RushChallenges.unlock_rift(MobileCore.save):circuits(true)
				else:toast("Need 600 coins or free storage.")
			else:game.stage=venue_index;game.start_run(),true,"lock" if not unlocked else "play")
		done.name="ConfirmFight";done.disabled=(MobileCore.save.data.coins<RushChallenges.SECRET_COST) if sealed else not unlocked
		footer.add_child(done)

func select_challenge(id:String) -> void:
	game.run_mode=id
	if id=="ladder":venue_index=0
	elif id=="rift":venue_index=5
	elif venue_index==5:venue_index=game.stage if game.stage in RushChallenges.ROUTE else 0
	circuits(true)

func cycle_venue(direction:int) -> void:
	venue_index=RushChallenges.cycle(venue_index,direction)
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
	var gesture:=column(.54,.57)
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
	var info:=column(.58,1)
	info.offset_bottom=-112
	var heading:=row()
	info.add_child(heading)
	var name:=label(fighter.name,38,PAPER,true)
	name.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	heading.add_child(name)
	heading.add_child(label("%d / %d"%[fighter_index+1,RushRoster.CHARACTERS.size()],17,MUTED))
	attribute_line(info,"POWER",fighter.damage,40,str(int(fighter.damage)),fighter.color)
	attribute_line(info,"HEALTH",fighter.hp,200,str(int(fighter.hp)),fighter.color)
	attribute_line(info,"SPEED",fighter.speed,6,"%.1f"%fighter.speed,fighter.color)
	var visual:=RushRoster.visual(fighter.move)
	var move_line:=row()
	info.add_child(move_line)
	move_line.add_child(icon(visual.icon,visual.color,30))
	move_line.add_child(label(visual.short+"  ·  "+visual.tag,18,visual.color,true))
	var passive:=body_text(fighter.passive,15)
	info.add_child(passive)
	info.add_child(body_text("E / "+RushUltimates.title(fighter.id),15,AMBER))
	var owned:=RushRoster.owned(MobileCore.save,"character",fighter.id)
	var selected:bool=game.selected_character().id==fighter.id
	var bottom:=column(1,1)
	bottom.offset_top=-94
	bottom.offset_bottom=-28
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
	game.player.visible=false;game.podium.visible=false
	var backdrop:=RushMenuBackdrop.new();backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);screen.add_child(backdrop)
	showroom_header("SKILLS")
	var selected:Dictionary=RushRoster.MOVES[move_index]
	var visual:=RushRoster.visual(selected.id)
	var rank:=RushSkillGrowth.level(MobileCore.save,selected.id)
	var power:=RushSkillGrowth.stats(rank)
	var forecast:=RushGrowth.snapshot(MobileCore.save,game.selected_character(),selected.id)
	var actual_cooldown:float=selected.cooldown*power.cooldown*forecast.cooldown*(1-float(game.selected_character().get("cooldown_bonus",0)))
	var scroll:=ScrollContainer.new();scroll.name="SkillsScroll"
	scroll.anchor_left=0;scroll.anchor_right=1;scroll.anchor_top=.15;scroll.anchor_bottom=1
	scroll.offset_left=28;scroll.offset_right=-28;scroll.offset_bottom=-198
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;screen.add_child(scroll)
	var col:=VBoxContainer.new();col.name="SkillDetails";col.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation",12);scroll.add_child(col)
	var grid:=GridContainer.new();grid.columns=3
	grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",10);col.add_child(grid)
	for i in RushRoster.MOVES.size():
		var move:Dictionary=RushRoster.MOVES[i];var look:=RushRoster.visual(move.id)
		var tile:=button("",func():move_index=i;moves(true));tile.name="Move_"+move.id
		tile.custom_minimum_size=Vector2(0,108);tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var bg:=style(Color("203541") if i==move_index else Color("101e2b"),12)
		if i==move_index:bg.set_border_width_all(2);bg.border_color=look.color
		tile.add_theme_stylebox_override("normal",bg)
		var symbol:=icon(look.icon,RushSkillGrowth.tint(move.id,RushSkillGrowth.level(MobileCore.save,move.id)),38)
		symbol.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP);symbol.offset_left=-19;symbol.offset_right=19;symbol.offset_top=12;symbol.offset_bottom=50;tile.add_child(symbol)
		var title:=label(look.short,19,PAPER,true);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		title.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);title.offset_top=-51;title.offset_bottom=-26;tile.add_child(title)
		var state:=label("LV %d%s"%[RushSkillGrowth.level(MobileCore.save,move.id)," / EQUIPPED" if game.selected_move()==move.id else ""] if RushRoster.owned(MobileCore.save,"move",move.id) else "%d COINS"%move.price,11,look.color)
		state.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;state.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);state.offset_top=-25;state.offset_bottom=-8;tile.add_child(state);grid.add_child(tile)
	spacer(col,8)
	var title:=row();col.add_child(title)
	var name:=label(visual.short,32,visual.color,true);name.size_flags_horizontal=Control.SIZE_EXPAND_FILL;title.add_child(name)
	title.add_child(label("LV %d / 10"%rank,24,AMBER,true))
	col.add_child(body_text(visual.hint,16,PAPER))
	var stats_row:=row();col.add_child(stats_row)
	for data in [["fist","+%d%%"%roundi((power.damage-1)*100)],["target","+%.1f%%"%((power.radius-1)*100)],["bolt","%.1fs"%actual_cooldown]]:
		var cell:=row();cell.size_flags_horizontal=Control.SIZE_EXPAND_FILL;stats_row.add_child(cell);cell.add_child(icon(data[0],visual.color,25));cell.add_child(label(data[1],21,PAPER,true))
	var progress:=bar(visual.color,7);progress.value=float(rank)/10*100;col.add_child(progress)
	var milestones:=row();milestones.add_theme_constant_override("separation",8);col.add_child(milestones)
	for step in [[1,"BASE","fist"],[5,"AWAKEN","nova"],[10,"ASCEND","crown"]]:
		var tile:=PanelContainer.new();tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tile.add_theme_stylebox_override("panel",style(Color("264347") if rank>=step[0] else Color("172435"),10));milestones.add_child(tile)
		var inside:=VBoxContainer.new();tile.add_child(inside)
		var symbol:=icon(step[2],visual.color if rank>=step[0] else MUTED,24);symbol.size_flags_horizontal=Control.SIZE_SHRINK_CENTER;inside.add_child(symbol)
		var caption:=label("%s / %d"%[step[1],step[0]],15,PAPER,true);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;inside.add_child(caption)
	var book:=button("PASSIVE PLAYBOOK",skills,false,"book");book.custom_minimum_size.y=42;book.add_theme_font_size_override("font_size",18);col.add_child(book)
	var bottom:=column(1,1);bottom.name="SkillActions";bottom.offset_top=-174;bottom.offset_bottom=-24
	var actions:=row();bottom.add_child(actions)
	var demo:=button("TRY EFFECT",func():game.demo_move(selected.id),false,"play");demo.name="TryEffect";demo.size_flags_horizontal=Control.SIZE_EXPAND_FILL;demo.add_theme_font_size_override("font_size",20);actions.add_child(demo)
	var owned:=RushRoster.owned(MobileCore.save,"move",selected.id)
	var equipped:bool=game.selected_move()==selected.id
	var equip:=button("EQUIPPED" if equipped else ("EQUIP" if owned else "%d COINS"%selected.price),func():
		if not RushRoster.unlock(MobileCore.save,"move",selected.id):toast("Need more coins or free storage.");return
		if not RushRoster.equip(MobileCore.save,"move",selected.id):toast("Selection could not be saved.");return
		game.technique_id=selected.id;moves(true),false,visual.icon)
	equip.size_flags_horizontal=Control.SIZE_EXPAND_FILL;equip.add_theme_font_size_override("font_size",20)
	equip.disabled=equipped or (not owned and MobileCore.save.data.coins<selected.price);actions.add_child(equip)
	var upgrade:=button("MAX LEVEL" if rank==10 else ("UPGRADE / %d COINS"%RushSkillGrowth.cost(rank) if owned else "UNLOCK TO UPGRADE"),func():
		if RushSkillGrowth.buy(MobileCore.save,selected.id):moves(true);toast("%s / LEVEL %d"%[visual.short,rank+1])
		else:toast("Need more coins or free storage."),true,"bolt")
	upgrade.name="UpgradeSkill";upgrade.disabled=not owned or rank==10 or MobileCore.save.data.coins<RushSkillGrowth.cost(rank);bottom.add_child(upgrade)

func _card_grid(parent:Control) -> GridContainer:
	var grid:=GridContainer.new();grid.columns=2
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(grid)
	return grid

func _visual_card(parent:Control,title:String,art:String,tint:Color,detail:String,cta:String,action:Callable,disabled:bool=false,compact:bool=false) -> Button:
	var panel:=PanelContainer.new();panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var surface:=style(Color("162c45"),16)
	surface.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel",surface);parent.add_child(panel)
	var col:=VBoxContainer.new();col.add_theme_constant_override("separation",6);panel.add_child(col)
	var image:=RushRewardArt.new();image.kind=art;image.tint=tint
	image.custom_minimum_size=Vector2(0,52 if compact else 72);col.add_child(image)
	var heading:=label(title,22 if compact else 24,PAPER,true);heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	heading.custom_minimum_size.y=28 if compact else 30
	heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;col.add_child(heading)
	var sub:=body_text(detail,14,Color("c4d9ed"));sub.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	sub.custom_minimum_size.y=20 if compact else 36;sub.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var buy:=button(cta,action,true)
	buy.custom_minimum_size.y=46;buy.add_theme_font_size_override("font_size",22)
	for state in ["normal","hover","pressed","disabled"]:
		var skin:=buy.get_theme_stylebox(state).duplicate()
		skin.content_margin_top=8;skin.content_margin_bottom=8
		buy.add_theme_stylebox_override(state,skin)
	buy.disabled=disabled;buy.set_meta("permanent_disabled",disabled)
	col.add_child(buy)
	return buy

func training() -> void:
	var fighter:Dictionary=game.selected_character()
	var rank:=RushTraining.league(MobileCore.save);var color:Color=RushTraining.COLORS[rank]
	var col:=page("GYM","%d COINS / %s CLUB"%[MobileCore.save.data.coins,RushTraining.RANKS[rank]],"training",game.go_home)
	col.get_parent().anchor_bottom=1;col.get_parent().offset_bottom=-120
	var top:=row();col.add_child(top);top.add_child(icon("crown",color,42))
	var summary:=VBoxContainer.new();summary.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(summary)
	summary.add_child(label("%d / 240 TRAINING"%RushTraining.total(MobileCore.save),25,color,true))
	var progress:=bar(color,7);progress.value=RushTraining.total(MobileCore.save)/240.0*100;summary.add_child(progress)
	var filters:=row();col.add_child(filters)
	for name in ["ALL","BODY","TECH","REWARDS"]:
		var filter:=button(name,func():gym_filter=name;training(),gym_filter==name);filter.custom_minimum_size.y=42;filter.size_flags_horizontal=Control.SIZE_EXPAND_FILL;filter.add_theme_font_size_override("font_size",18);filters.add_child(filter)
	col.add_child(button("COMPANION EQUIPMENT",equipment,false,"shield"))
	var grid:=_card_grid(col)
	for entry in RushBalance.TRAINING:
		var category:String="BODY" if entry.id in ["power","health","grit"] else ("TECH" if entry.id in ["charge","footwork","mastery"] else "REWARDS")
		if gym_filter!="ALL" and gym_filter!=category:continue
		var level:=RushTraining.level(MobileCore.save,entry.id);var tier:=RushTraining.tier(level)
		var current:=RushTraining.display_value(fighter,entry.id,level)
		var next:=RushTraining.display_value(fighter,entry.id,mini(30,level+1))
		var title:String={"power":"POWER","health":"HEALTH","charge":"ENERGY","footwork":"SPEED","mastery":"COOLDOWN","grit":"RESILIENCE","recovery":"RECOVERY","fortune":"COIN BONUS"}[entry.id]
		var cost:=RushBalance.training_cost(level)
		var b:=_visual_card(grid,title,entry.icon,RushTraining.COLORS[tier],current+(" > "+next if level<30 else " / MAX"),"MAX" if level==30 else "+ %d COINS"%cost,func():
			if RushTraining.buy(MobileCore.save,entry.id):training();toast(title+" / LEVEL %d"%(level+1))
			else:toast("Need more coins or free storage."),level==30 or MobileCore.save.data.coins<cost,true)
		b.name="Train_"+entry.id
		var stack:VBoxContainer=b.get_parent()
		var title_rank:=label("%s / %d"%[RushTraining.RANKS[tier],level],14,RushTraining.COLORS[tier]);title_rank.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;stack.add_child(title_rank);stack.move_child(title_rank,2)
		var art:RushRewardArt=stack.get_child(0);art.level=posmod(maxi(1,level)-1,5)+1 if level>0 else 0
	col.add_child(body_text("Recovery: after each wave. Resilience: less damage taken. Coin bonus: paid at fight end.",14))
	var forecast:=RushGrowth.snapshot(MobileCore.save,fighter,game.selected_move(),game.challenge_contract)
	col.add_child(body_text("RIVALS / +%d%% HP / +%d%% POWER"%[roundi((forecast.enemy_hp-1)*100),roundi((forecast.enemy_damage-1)*100)],15,color))
	var contract:=button("CONTRACT ON / +25% COINS" if game.challenge_contract else "HARD CONTRACT / +25% COINS",func():game.challenge_contract=not game.challenge_contract;training(),game.challenge_contract,"flame")
	contract.name="Contract";contract.add_theme_font_size_override("font_size",20);col.add_child(contract)
	col.add_child(body_text("Optional: rivals gain +30% base HP and +20% base damage. Applies to your next fight.",14))
	var footer:=column(1,1);footer.offset_top=-94;footer.offset_bottom=-24
	var actions:=row();footer.add_child(actions)
	var badges:=button("BADGES",achievements,false,"crown");badges.size_flags_horizontal=Control.SIZE_EXPAND_FILL;actions.add_child(badges)
	var fight:=button("RESUME" if game.has_resume() else "PLAY",func():
		if game.has_resume():game.resume_saved_run()
		else:circuits(),true,"play")
	fight.name="GymFight";fight.size_flags_horizontal=Control.SIZE_EXPAND_FILL;actions.add_child(fight)

func achievements() -> void:
	var earned:Dictionary=MobileCore.save.data.progress.get("badges",{})
	var bonus:=RushAchievements.bonuses(MobileCore.save.data)
	var col:=page("BADGES","%d / 42 BADGES · 3 STAGES EACH"%earned.size(),"achievements",game.go_home)
	col.add_child(body_text("+%.1f HP / +%.2f POWER / -%.2f%% COOLDOWN"%[bonus.health,bonus.power,bonus.cooldown*100],17,AMBER))
	var filters:=GridContainer.new();filters.columns=3;filters.add_theme_constant_override("h_separation",8);filters.add_theme_constant_override("v_separation",8);col.add_child(filters)
	for name in ["ALL","COMBAT","VICTORIES","GROWTH","STYLE"]:
		var tab:=button(name,func():badge_filter=name;achievements(),badge_filter==name);tab.custom_minimum_size.y=40;tab.add_theme_font_size_override("font_size",18);tab.size_flags_horizontal=Control.SIZE_EXPAND_FILL;filters.add_child(tab)
	var grid:=_card_grid(col)
	for badge in RushAchievements.catalog():
		if badge_filter!="ALL" and badge.category!=badge_filter:continue
		var tier:=RushAchievements.rank(MobileCore.save.data,badge.id)
		var next_tier:=mini(3,tier+1);var goal:=RushAchievements.target(badge,next_tier)
		var tier_color:Color=[MUTED,Color("dca47b"),Color("c7dbea"),AMBER][tier]
		var done:=tier==3;var value:=mini(goal,RushAchievements.metric(MobileCore.save.data,badge.metric))
		var panel:=PanelContainer.new();panel.name="Badge_"+badge.id;panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var skin:=style(Color("28463f") if done else Color("162c45"),14);skin.set_content_margin_all(12);panel.add_theme_stylebox_override("panel",skin);grid.add_child(panel)
		var content:=VBoxContainer.new();content.add_theme_constant_override("separation",8);panel.add_child(content)
		var art:=RushRewardArt.new();art.kind=badge.icon;art.tint=tier_color;art.custom_minimum_size.y=54;content.add_child(art)
		var stages:=row();stages.alignment=BoxContainer.ALIGNMENT_CENTER;content.add_child(stages)
		for i in 3:
			var dot:=ColorRect.new();dot.custom_minimum_size=Vector2(28,5);dot.color=tier_color if i<tier else Color("344c64");stages.add_child(dot)
		var title:=body_text(badge.title,22,PAPER);title.add_theme_font_override("font",DISPLAY);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.custom_minimum_size.y=52;title.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;content.add_child(title)
		var detail:=body_text(RushAchievements.requirement(badge,next_tier),13);detail.custom_minimum_size.y=36;detail.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;content.add_child(detail)
		var progress:=bar(AMBER if done else TEAL,6);progress.value=float(value)/goal*100;content.add_child(progress)
		var count:=label("GOLD COMPLETE" if done else "%s · %d / %d"%[RushAchievements.TIERS[tier],value,goal],14,AMBER if done else TEAL);count.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;content.add_child(count)
		var gate:=body_text(RushAchievements.gate_text(next_tier) if not done else "ALL 3 STAGES EARNED",12,MUTED);gate.custom_minimum_size.y=48;gate.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;content.add_child(gate)
		var reward:=label(RushAchievements.reward(badge),14,PAPER);reward.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;content.add_child(reward)

func skills() -> void:
	var in_run: bool = game.mode == "paused"
	var col := page("YOUR BUILD" if in_run else "THE PLAYBOOK", "23 stackable skills · Ranged choices every level · Q: technique / E: fighter ultimate","skills",paused if in_run else home)
	col.add_child(label("E / "+RushUltimates.title(game.player.character_id),23,AMBER,true))
	col.add_child(body_text(RushUltimates.description(game.player.character_id),16))
	if in_run:
		col.add_child(body_text("Damage %.0f   ·   Reach %.1fm   ·   Punch every %.2fs" % [game.damage,game.reach,game.cooldown],17,TEAL))
	col.add_child(label("ACTIVE MOVES",28,PAPER,true))
	col.add_child(body_text("DASH / SPACE — slip through danger with brief invulnerability.\nTECHNIQUE / Q — your equipped move, recharging on a cooldown.\nULTIMATE / E — your fighter's unique limit break, charged with knockouts.",17))
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
	var col:=page("SHOP","%d COINS  ·  Free test purchases"%MobileCore.save.data.coins if test else "%d COINS"%MobileCore.save.data.coins,"shop",game.go_home)
	var grid:=_card_grid(col)
	var ads:bool=game.ads_removed()
	_visual_card(grid,"NO ADS","shield",TEAL,"Reward videos stay","OWNED" if ads else ("TEST UNLOCK" if test else "UNAVAILABLE"),func():MobileCore.commerce.buy("remove_ads"),ads or not test)
	var gold:bool=MobileCore.save.data.entitlements.get("gold_gloves",false)
	_visual_card(grid,"GOLD GLOVES","fist",AMBER,"Every fighter","OWNED" if gold else ("TEST UNLOCK" if test else "UNAVAILABLE"),func():MobileCore.commerce.buy("gold_gloves"),gold or not test)
	for id in ["coins_500","coins_1500","coins_4000"]:
		var pack:Dictionary=RushBalance.PRODUCTS[id]
		_visual_card(grid,"%d COINS"%pack.coins,id,AMBER,"Fighters · Skills · Stats","TEST FREE" if test else "UNAVAILABLE",func():MobileCore.commerce.buy(id),not test)
	_visual_card(grid,"60 COINS","ad",TEAL,"Optional reward video","WATCH" if test else "UNAVAILABLE",func():MobileCore.commerce.reward("training_coins"),not test)
	var links:=row();col.add_child(links)
	for entry in [["GYM",training,"fist"],["RESTORE",func():MobileCore.commerce.restore(),"shield"]]:
		var b:=button(entry[0],entry[1],false,entry[2]);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;links.add_child(b)
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
	for entry in [["effects","EXTRA PARTICLES & IMPACT FLASH"],["haptics","HAPTIC FEEDBACK"],["sound","SOUND EFFECTS"],["music","MUSIC"],["low_quality","BATTERY SAVER"]]:
		var key: String = entry[0]
		var enabled: bool = MobileCore.save.data.settings.get(key,key!="low_quality")
		col.add_child(button(entry[1]+"  /  "+("ON" if enabled else "OFF"),func():
			if MobileCore.save.set_setting(key,not enabled):
				game.apply_settings()
				settings()
			else: toast("Could not save settings. Free storage and try again.")))
	var reduced:=button("REDUCED MOTION: " + ("ON" if MobileCore.save.data.settings.get("reduced_motion",false) else "OFF"),func():MobileCore.save.set_setting("reduced_motion",not MobileCore.save.data.settings.get("reduced_motion",false));settings())
	col.add_child(reduced)
	col.add_child(body_text("Skill trails and enemy warnings always remain visible. Extra particles adds sparks, damage numbers and camera shake. Battery saver reduces shadows and scenery detail.",16))
	spacer(col)
	col.add_child(body_text("Touch: drag to move; use dodge, technique and ultimate.\nKeyboard: WASD / arrows, Space to dodge, Q for technique, E for ultimate, Esc to pause.\nRuns pause when the app loses focus.",17))

	spacer(col,20)
	col.add_child(body_text(RushReleaseInfo.version(),16,AMBER))
	col.add_child(button("SUPPORT",support_page,false,"heart"))
	col.add_child(button("PRIVACY",privacy_page,false,"shield"))
	col.add_child(button("CREDITS & LICENSES",credits_page,false,"crown"))

func equipment() -> void:
	var col:=page("COMPANIONS","%d COINS · ONE AIR + ONE GROUND"%MobileCore.save.data.coins,"equipment",game.go_home)
	var catalog:ScrollContainer=col.get_parent();catalog.name="EquipmentCatalog"
	catalog.offset_top=250
	var loadout:=HBoxContainer.new();loadout.name="EquippedLoadout"
	loadout.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);loadout.anchor_top=.18;loadout.anchor_bottom=.18
	loadout.offset_left=28;loadout.offset_right=-28;loadout.offset_top=0;loadout.offset_bottom=244
	loadout.add_theme_constant_override("separation",12);screen.add_child(loadout)
	for slot in ["air","ground"]:_equipped_card(loadout,slot)
	var filter_row:=row();col.add_child(filter_row)
	for filter in ["ALL","AIR","GROUND"]:
		var b:=button(filter,func():equipment_filter=filter;equipment(),equipment_filter==filter)
		b.custom_minimum_size.y=38;b.add_theme_font_size_override("font_size",18);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;filter_row.add_child(b)
	col.add_child(body_text("Loadout changes apply to your next fight.",13,MUTED))
	var grid:=_card_grid(col)
	for entry in RushEquipment.ITEMS:
		if equipment_filter!="ALL" and entry.slot.to_upper()!=equipment_filter:continue
		var owned:=RushEquipment.owned(MobileCore.save,entry.id);var selected:bool=RushEquipment.selected(MobileCore.save,entry.slot)==entry.id
		var b:=_visual_card(grid,entry.name,entry.icon,entry.color,entry.trigger+"\n"+entry.effect,"EQUIPPED" if selected else ("EQUIP" if owned else "%d COINS"%entry.price),func():
			var ok:bool=RushEquipment.equip(MobileCore.save,entry.slot,entry.id) if owned else RushEquipment.buy(MobileCore.save,entry.id)
			if ok:equipment();toast("EQUIPPED" if owned else "UNLOCKED / TAP EQUIP")
			else:toast("Need more coins or free storage."),selected or (not owned and MobileCore.save.data.coins<entry.price))
		b.name="Equip_"+entry.id
		var stack:VBoxContainer=b.get_parent()
		var detail:Label=stack.get_child(2);detail.custom_minimum_size.y=66;detail.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		var path:String="res://assets/creatures/thumbs/"+entry.model+".png"
		if ResourceLoader.exists(path):
			var old:Control=stack.get_child(0);stack.remove_child(old);old.queue_free()
			var art:=TextureRect.new();art.texture=load(path);art.custom_minimum_size=Vector2(0,120);art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;stack.add_child(art);stack.move_child(art,0)
		var slot_label:=label(entry.slot.to_upper(),12,entry.color);slot_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;stack.add_child(slot_label);stack.move_child(slot_label,0)
		var cooldown:=label("%ds CD%s"%[entry.cooldown," · 3 USES / RUN" if entry.charges>0 else ""],12,MUTED);cooldown.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;stack.add_child(cooldown)

func _equipped_card(parent:Control,slot:String) -> void:
	var entry:=RushEquipment.item(RushEquipment.selected(MobileCore.save,slot))
	var tint:Color=entry.get("color",Color("79949e"))
	var panel:=PanelContainer.new();panel.name="EquippedCard_"+slot;panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var surface:=style(Color("172f3c") if slot=="air" else Color("273336"),16)
	surface.border_color=tint.darkened(.5);surface.set_border_width_all(1);surface.content_margin_left=12;surface.content_margin_right=12;surface.content_margin_top=10;surface.content_margin_bottom=10
	panel.add_theme_stylebox_override("panel",surface);parent.add_child(panel)
	var stack:=VBoxContainer.new();stack.add_theme_constant_override("separation",4);panel.add_child(stack)
	var slot_name:=label(slot.to_upper()+" SUPPORT",13,tint);slot_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;stack.add_child(slot_name)
	if not entry.is_empty():
		var art:=TextureRect.new();art.name="EquippedPreview";art.texture=load("res://assets/creatures/thumbs/"+entry.model+".png")
		art.custom_minimum_size=Vector2(0,86);art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;stack.add_child(art)
	else:
		var art:=CenterContainer.new();art.custom_minimum_size.y=86;art.add_child(icon("orbit" if slot=="air" else "shield",tint,46));stack.add_child(art)
	var title:=label(entry.get("name","EMPTY SLOT"),22,PAPER,true);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.clip_text=true;stack.add_child(title)
	var effect:=body_text(entry.trigger+"\n"+entry.effect if not entry.is_empty() else "Choose an automatic helper",13,tint);effect.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;effect.custom_minimum_size.y=34;effect.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;stack.add_child(effect)
	var actions:=row();stack.add_child(actions)
	var change:=button("CHOOSE" if entry.is_empty() else "CHANGE",func():equipment_filter=slot.to_upper();equipment())
	change.name="Choose_"+slot;change.custom_minimum_size.y=38;change.add_theme_font_size_override("font_size",18);change.size_flags_horizontal=Control.SIZE_EXPAND_FILL;actions.add_child(change)
	if not entry.is_empty():
		var remove:=button("×",func():
			if RushEquipment.equip(MobileCore.save,slot,""):equipment()
			else:toast("Could not save equipment."))
		remove.name="Remove_"+slot;remove.tooltip_text="UNEQUIP "+entry.name;remove.custom_minimum_size=Vector2(38,38);remove.add_theme_font_size_override("font_size",22);actions.add_child(remove)

func support_page() -> void:
	var data:=RushReleaseInfo.config()
	var col:=page("SUPPORT",RushReleaseInfo.version(),"support",settings)
	col.add_child(body_text("Found a bug? Include the version, device, what happened and the steps to reproduce. A screenshot helps.",18))
	col.add_child(button("EMAIL SUPPORT",func():OS.shell_open("mailto:"+data.support_email+"?subject="+("RingRush "+data.version).uri_encode()),true,"heart"))
	col.add_child(body_text(data.support_email,18,TEAL))
	col.add_child(button("COPY DEVICE SUMMARY",func():DisplayServer.clipboard_set(RushReleaseInfo.diagnostics());toast("Device summary copied."),false,"gear"))
	col.add_child(button("ZX LABS WEBSITE",func():OS.shell_open(data.website),false,"play"))
	col.add_child(body_text("Copy includes version, platform and renderer only. Nothing is sent automatically.",15))

func privacy_page() -> void:
	var col:=page("PRIVACY","LOCAL PLAYTEST", "privacy",settings)
	col.add_child(body_text("This build saves progress and settings on this device or in this browser. Clearing browser data or removing the app can erase progress. There is no account or cloud save.",18))
	col.add_child(body_text("Advertising and purchases are simulations in the playtest. No live ad network, billing SDK, analytics or push notification service is connected in this build. Support opens your email app; sending a message is your choice.",18))
	col.add_child(body_text("A published privacy policy and platform data disclosures must be completed before store release. This local notice describes the current playtest only.",16,AMBER))
	var url:String=RushReleaseInfo.config().get("privacy_url","")
	if not url.is_empty():col.add_child(button("PRIVACY POLICY",func():OS.shell_open(url),true,"shield"))

func credits_page() -> void:
	var col:=page("CREDITS","ASSETS · SOFTWARE · LICENSES", "credits",settings)
	for entry in RushReleaseInfo.credits():
		col.add_child(label(entry.title,25,TEAL,true));col.add_child(label(entry.author,17,PAPER));col.add_child(body_text(entry.detail,15))
		var actions:=row();col.add_child(actions)
		var source:=button("SOURCE",func():OS.shell_open(entry.url));source.size_flags_horizontal=Control.SIZE_EXPAND_FILL;actions.add_child(source)
		if not entry.license.is_empty():
			var license_button:=button("LICENSE",func():license_page(entry));license_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;actions.add_child(license_button)
		spacer(col,16)

func license_page(entry:Dictionary) -> void:
	var col:=page(entry.title,entry.author,"license",credits_page)
	col.add_child(body_text(FileAccess.get_file_as_string(entry.license),14))

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

func toast(text:String) -> void:
	MobileCore.notices.post(text)

func _present_notice(text: String) -> void:
	message.text = text
	var success:bool="CLEAR" in text or "RECOVERY" in text
	var surface:=style(Color("147b72") if success else Color("214c8d"),12)
	surface.set_border_width_all(1)
	surface.border_color=TEAL if success else Color("73b9ff")
	message.add_theme_stylebox_override("normal",surface)
	message.visible = true
	if toast_tween!=null:toast_tween.kill()
	message.modulate.a=1
	if _motion_enabled():
		message.modulate.a=.3
		toast_tween=create_tween()
		toast_tween.tween_property(message,"modulate:a",1.0,.18)
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
