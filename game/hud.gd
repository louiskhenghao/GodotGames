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
var special_button: Button
var buttons: Array[Button] = []
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
	message.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	message.offset_left = 24
	message.offset_right = -24
	message.offset_top = -56
	message.offset_bottom = -12
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
	# A second finger can use skills while the first finger steers.
	if current_page != "playing" or not event is InputEventScreenTouch or not event.pressed: return
	for b in buttons:
		if is_instance_valid(b) and not b.disabled and b.get_global_rect().has_point(event.position):
			b.pressed.emit()
			get_viewport().set_input_as_handled()
			return

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
	if game.mode != "playing":
		screen.modulate.a = 0.65
		transition = create_tween()
		transition.tween_property(screen, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

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
	var top := column(0.045, 0.26)
	var header := row()
	top.add_child(header)
	var name_label := label("RING RUSH", 56, PAPER, true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	header.add_child(icon("coin", AMBER))
	header.add_child(label(str(int(MobileCore.save.data.coins)), 27, AMBER, true))
	top.add_child(label("YOUR NEXT ROUND STARTS HERE.", 17, MUTED))
	var record := label("BEST  %d KO" % int(MobileCore.save.data.progress.get("best_kos", 0)), 18, TEAL, true)
	top.add_child(record)
	var name_plate := column(0.61, 0.69)
	var title := label("THE CHALLENGER", 29, PAPER, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_plate.add_child(title)
	var equipment := label("GOLD EDITION" if MobileCore.save.data.entitlements.get("gold_gloves", false) else "CYAN CORNER  /  READY TO FIGHT", 13, TEAL)
	equipment.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_plate.add_child(equipment)
	var bottom := column(0.705, 0.96)
	var stage_row := row()
	bottom.add_child(stage_row)
	var stage_button := button("CIRCUIT %d  /  %s" % [game.stage+1, RushBalance.STAGES[game.stage].name], circuits, false, "crown")
	stage_button.add_theme_font_size_override("font_size", 21)
	stage_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_button.custom_minimum_size.y = 51
	stage_row.add_child(stage_button)
	var play := button("ENTER THE RING", game.start_run, true, "fist")
	play.custom_minimum_size.y = 68
	play.add_theme_font_size_override("font_size", 29)
	bottom.add_child(play)
	var nav := row()
	bottom.add_child(nav)
	for entry in [["GYM",training,"fist"],["SKILLS",skills,"book"],["LOCKER",shop,"crown"],["",settings,"gear"]]:
		var b := button(entry[0],entry[1],false,entry[2])
		b.add_theme_font_size_override("font_size",18)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if entry[0].is_empty(): b.custom_minimum_size.x = 54; b.size_flags_horizontal = Control.SIZE_SHRINK_END
		nav.add_child(b)
	_busy(not MobileCore.commerce.pending.is_empty())

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
	var top := column(0.04, 0.24)
	var header := row()
	top.add_child(header)
	stats = label("", 27, PAPER, true)
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(stats)
	var pause := button("",game.pause_run,false,"pause")
	pause.custom_minimum_size = Vector2(55,52)
	header.add_child(pause)
	var health_row := row()
	top.add_child(health_row)
	hp_text = label("",15,TEAL)
	hp_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_row.add_child(hp_text)
	combo_text = label("",17,AMBER,true)
	health_row.add_child(combo_text)
	health_bar = bar(TEAL,12)
	top.add_child(health_bar)
	xp_bar = bar(AMBER,5)
	top.add_child(xp_bar)
	boss_title = label("",18,Color("ff8470"),true)
	top.add_child(boss_title)
	boss_bar = bar(Color("f57e6a"),6)
	top.add_child(boss_bar)
	var bottom := column(0.79,0.96)
	hint = label("Drag to move. Punches are automatic.",15,MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(hint)
	if not game.ranks.is_empty():
		var equipped := row()
		equipped.alignment = BoxContainer.ALIGNMENT_CENTER
		bottom.add_child(equipped)
		var shown := 0
		for id in game.ranks:
			if shown >= 6: break
			var entry := RushBalance.ability(id)
			if entry.is_empty(): continue
			equipped.add_child(icon(entry.icon,TEAL,24))
			shown += 1
	var actions := row()
	bottom.add_child(actions)
	dash_button = button("DASH  /  SPACE",game.dash,false,"dash")
	dash_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dash_button.custom_minimum_size.y = 70
	dash_button.add_theme_font_size_override("font_size",21)
	actions.add_child(dash_button)
	special_button = button("SPECIAL  /  E",game.special,true,"nova")
	special_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	special_button.custom_minimum_size.y = 70
	special_button.add_theme_font_size_override("font_size",21)
	actions.add_child(special_button)
	var help := label("Dodge through danger. Charge your special with knockouts.",13,MUTED)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(help)
	update_stats()
	call_deferred("_block_actions")

func _block_actions() -> void:
	if current_page != "playing": return
	stick.blocked_rects.clear()
	for b in buttons:
		if is_instance_valid(b): stick.blocked_rects.append(b.get_global_rect())

func update_stats() -> void:
	if not is_instance_valid(stats): return
	stats.text = "%02d:%02d    WAVE %d    %d KO" % [int(game.remaining)/60,int(game.remaining)%60,game.wave,game.kills]
	hp_text.text = "HEALTH  %d / %d     LEVEL %d" % [ceili(game.hp),int(game.max_hp),game.level]
	combo_text.text = "%d COMBO" % game.combo if game.combo > 1 else ""
	health_bar.value = clampf(game.hp/game.max_hp*100,0,100)
	xp_bar.value = clampf(float(game.xp)/game.xp_needed*100,0,100)
	var boss_alive: bool = game.boss != null and game.boss.active
	boss_title.visible = boss_alive
	boss_bar.visible = boss_alive
	if boss_alive:
		boss_title.text = RushBalance.STAGES[game.stage].boss + ("  /  OVERTIME" if game.remaining <= 0 else "")
		boss_bar.value = game.boss.health / game.boss.max_health * 100
	dash_button.disabled = game.dash_clock > 0
	dash_button.text = "DASH  %.1fs" % game.dash_clock if game.dash_clock > 0 else ("DASH" if touch_device else "DASH  /  SPACE")
	special_button.disabled = game.special_charge < 100
	special_button.text = "SPECIAL  %d%%" % game.special_charge if game.special_charge < 100 else ("UNLEASH" if touch_device else "UNLEASH  /  E")
	if game.elapsed > 6: hint.text = "%d SKILLS EQUIPPED     %d COINS EARNED" % [game.ranks.size(),game.run_coins]

func page(title: String, detail: String, page_name: String, back: Callable = Callable()) -> VBoxContainer:
	clear(page_name)
	var shade := ColorRect.new()
	shade.color = Color(0.025,0.055,0.09,0.97)
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
	var symbol := icon(entry.icon,TEAL,40)
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
	text.add_child(label(entry.tag + ("    RANK %d → %d" % [rank,rank+1] if choice else "    %d / %d" % [rank,entry.max]),12,TEAL))
	for child in text.get_children(): child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

func abilities(options: Array) -> void:
	var col := page("CHOOSE YOUR EDGE", "Level %d. Pick one skill for this run." % game.level,"upgrade")
	for entry in options:
		col.add_child(ability_card(entry,func():game.choose_ability(entry.id),true))
	spacer(col,8)
	var reroll := button("REROLL CHOICES  /  %d LEFT" % game.rerolls,game.reroll,false,"orbit")
	reroll.disabled = game.rerolls <= 0
	col.add_child(reroll)
	col.add_child(body_text("Skills stack up to their maximum rank. Combine fire, ice and lightning with stronger punches.",15))

func paused() -> void:
	var col := page("IN YOUR CORNER", "The clock is stopped. Your fight will wait.","paused")
	col.add_child(button("BACK TO THE FIGHT",game.resume_run,true,"fist"))
	col.add_child(button("VIEW YOUR BUILD",skills,false,"book"))
	col.add_child(button("SETTINGS",settings,false,"gear"))
	col.add_child(button("END RUN & BANK COINS",func():game.finish_run(false)))
	spacer(col,14)
	col.add_child(body_text("Move: drag or WASD / arrows\nDash: Space or the dash button\nSpecial: E when fully charged\nRed circles warn of incoming attacks.",18))

func result(won: bool, saved: bool) -> void:
	var col := page("BELT EARNED." if won else "FIGHT ANOTHER DAY.", "Circuit %d · %s" % [game.stage+1,RushBalance.STAGES[game.stage].name],"result")
	var emblem := icon("crown" if won else "fist",AMBER,72)
	emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(emblem)
	var total := label("%d KNOCKOUTS" % game.kills,48,PAPER,true)
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(total)
	var info := label("LEVEL %d    /    %ds SURVIVED" % [game.level,int(game.elapsed)],17,MUTED)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(info)
	spacer(col)
	col.add_child(label("%d COINS %s" % [game.run_coins,"BANKED" if saved else "AWAITING SAVE"],30,AMBER,true))
	if won: col.add_child(body_text("Victory bonus included. " + ("The next circuit is now available." if game.stage < 2 else "You have conquered all three circuits."),17))
	if saved:
		col.add_child(button("ANOTHER ROUND",game.start_run,true,"fist"))
		col.add_child(button("RETURN TO GYM",game.go_home))
	else:
		col.add_child(body_text("Your reward could not be written. Free storage, then retry. Your coins will only be granted once.",17))
		col.add_child(button("RETRY SAVING REWARD",func():game.finish_run(won),true))

func circuits() -> void:
	var col := page("THE CIRCUIT", "Survive the crowd. Defeat the champion. Earn the next belt.","circuits",home)
	var unlocked := clampi(int(MobileCore.save.data.progress.get("unlocked_stage",0)),0,2)
	for i in 3:
		var entry: Dictionary = RushBalance.STAGES[i]
		var locked := i > unlocked
		var b := button("%d   %s" % [i+1,entry.name],func():game.select_stage(i),i==game.stage,"lock" if locked else "crown")
		b.disabled = locked
		b.add_theme_font_size_override("font_size",25)
		col.add_child(b)
		col.add_child(body_text("Win the previous circuit to unlock." if locked else entry.detail + "\nChampion: " + entry.boss + "  ·  Bonus: %d coins" % entry.reward,16))
		spacer(col,10)

func training() -> void:
	var col := page("THE GYM", "Permanent training. Your balance: %d coins." % MobileCore.save.data.coins,"training",home)
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
	var col := page("YOUR BUILD" if in_run else "THE PLAYBOOK", "18 stackable skills. Two active moves. Find your fighting style.","skills",paused if in_run else home)
	if in_run:
		col.add_child(body_text("Damage %.0f   ·   Reach %.1fm   ·   Punch every %.2fs" % [game.damage,game.reach,game.cooldown],17,TEAL))
	col.add_child(label("ACTIVE MOVES",28,PAPER,true))
	col.add_child(body_text("DASH / SPACE — slip through danger with brief invulnerability.\nSPECIAL / E — fill the meter with knockouts, then unleash a powerful shockwave.",17))
	spacer(col)
	for entry in RushBalance.ABILITIES:
		if in_run and game.rank_of(entry.id)==0: continue
		var card := ability_card(entry,Callable(),false)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.focus_mode = Control.FOCUS_NONE
		col.add_child(card)
	if in_run and game.ranks.is_empty(): col.add_child(body_text("No skills yet. Collect teal experience gems to level up.",18))

func shop() -> void:
	var test: bool = MobileCore.commerce.provider.is_mock
	var owned: bool = MobileCore.save.data.entitlements.get("gold_gloves",false)
	var col := page("THE LOCKER", "Development store · No real ads or charges." if test else "The native store is not connected in this build.","shop",home)
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
	for entry in [["effects","IMPACT EFFECTS"],["haptics","HAPTIC FEEDBACK"],["sound","SOUND EFFECTS"],["low_quality","BATTERY SAVER"]]:
		var key: String = entry[0]
		var enabled: bool = MobileCore.save.data.settings.get(key,key!="low_quality")
		col.add_child(button(entry[1]+"  /  "+("ON" if enabled else "OFF"),func():
			if MobileCore.save.set_setting(key,not enabled):
				game.apply_settings()
				settings()
			else: toast("Could not save settings. Free storage and try again.")))
	col.add_child(body_text("Battery saver disables real-time shadows, the audience and anti-aliasing. Gameplay and skill effects are unchanged.",16))
	spacer(col)
	col.add_child(body_text("Touch: drag to move; use the two skill buttons.\nKeyboard: WASD / arrows, Space to dash, E for special, Esc to pause.\nRuns pause when the app loses focus.",17))

func _commerce_completed(_success: bool,text: String) -> void:
	game.player.set_gold(MobileCore.save.data.entitlements.get("gold_gloves",false))
	if current_page == "shop": shop()
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
