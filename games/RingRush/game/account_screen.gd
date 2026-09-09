class_name RushAccountScreen
extends RefCounted
## RingRush presentation; account and synchronization behavior lives in mobile-core.
var status_label: Label
var email_field: LineEdit
var password_field: LineEdit
var action_buttons: Array[Button] = []
var signature := ""
var hud: RushHUD

func state_key() -> String:
	var account := MobileCore.account
	return account.user_id + str(account.verified) + str(not account.api.access_token.is_empty()) + JSON.stringify(account.conflict)

func show_page(owner: RushHUD) -> void:
	hud = owner
	action_buttons.clear()
	signature = state_key()
	var account := MobileCore.account
	var col := hud.page("ACCOUNT", "YOUR FIGHT. EVERY DEVICE.", "account", hud.home)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", hud.style(Color("173c43"), 18))
	col.add_child(card)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 8); card.add_child(box)
	box.add_child(hud.label("CLOUD SAVE" if account.verified else "PLAY ANYWHERE", 28, hud.TEAL, true))
	status_label = hud.body_text(account.status, 17, hud.PAPER)
	status_label.name = "AccountStatus"
	box.add_child(status_label)
	box.add_child(hud.body_text("Offline? Keep playing. Progress stays on this device and syncs when you reconnect.", 15))
	if account.verified and not account.conflict.is_empty():
		_choices(col)
	elif account.verified:
		col.add_child(hud.body_text(account.email, 18, hud.TEAL))
		_add(col, "SYNC NOW", account.sync_now, true, "orbit")
		col.add_child(hud.body_text("Last cloud save: " + str(MobileCore.save.data.get("cloud", {}).get("updated_at", "Not yet synced")).replace("T", " ").left(35), 15))
		_add(col, "SIGN OUT", account.logout, false, "back")
		col.add_child(hud.body_text("Signing out keeps this account’s offline progress here and returns to your separate guest profile.", 15))
	elif not account.api.access_token.is_empty():
		col.add_child(hud.body_text(account.email, 18, hud.TEAL))
		_add(col, "CHECK VERIFICATION", account.check_verification, true, "shield")
		_add(col, "RESEND EMAIL", func(): account.email_action("resend-verification", account.email))
		_add(col, "CANCEL SIGN IN", func(): account.api.forget(); show_page(hud))
	else:
		if not account.user_id.is_empty():
			col.add_child(hud.body_text("Playing the local copy for " + account.email + ". Sign in to upload your latest progress.", 16, hud.AMBER))
		email_field = _field(col, "Email", false)
		email_field.name = "AccountEmail"
		email_field.text = account.email
		password_field = _field(col, "Password · at least 12 characters", true)
		password_field.name = "AccountPassword"
		_add(col, "SIGN IN", _login, true, "shield")
		_add(col, "CREATE ACCOUNT", _register, false, "fist")
		_add(col, "FORGOT PASSWORD", func(): account.email_action("forgot-password", email_field.text))
		col.add_child(hud.body_text("Verify your email to enable cloud saves. For now, sign in again after reopening the game. Your local progress is kept.", 15))
		if not account.user_id.is_empty(): _add(col, "USE GUEST PROFILE", account.logout)
	_add(col, "BACK TO GAME", hud.home, false, "play")
	col.add_child(hud.body_text("Only synced progress can be recovered on another phone. Uninstalling the app or clearing browser data can erase unsynced progress.", 14))
	update()

func _field(parent: Control, hint: String, secret: bool) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = hint
	field.secret = secret
	field.max_length = 128 if secret else 254
	field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD if secret else LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	field.custom_minimum_size.y = 56
	field.add_theme_font_size_override("font_size", 17)
	field.add_theme_stylebox_override("normal", hud.style(Color("203346"), 12))
	field.add_theme_color_override("font_color", hud.PAPER)
	parent.add_child(field)
	return field

func _login() -> void:
	var password := password_field.text
	password_field.clear()
	MobileCore.account.login(email_field.text, password)

func _register() -> void:
	var password := password_field.text
	password_field.clear()
	MobileCore.account.email_action("register", email_field.text, password)

func _add(parent: Control, text: String, action: Callable, primary := false, glyph := "") -> void:
	var b := hud.button(text, action, primary, glyph)
	b.name = text.to_pascal_case()
	parent.add_child(b)
	action_buttons.append(b)

func _summary(data: Dictionary) -> String:
	return "%d COINS · %d FIGHTS\n%d KNOCKOUTS" % [int(data.get("coins", 0)), int(data.get("progress", {}).get("runs", 0)), int(data.get("progress", {}).get("total_kos", 0))]

func _choices(col: Control) -> void:
	var account := MobileCore.account
	if account.conflict.kind == "first":
		var guest := CoreSaveStore.new(account.guest_path); guest.load_profile()
		col.add_child(hud.body_text("No cloud save yet. Bring your guest progress or begin a fresh account. Your guest file is kept separately.", 17))
		col.add_child(hud.label(_summary(guest.data), 23, hud.AMBER, true))
		_add(col, "USE GUEST PROGRESS", func(): account.resolve("guest"), true, "fist")
		_add(col, "START FRESH", func(): account.resolve("new"))
		col.add_child(hud.body_text("Simulated paid unlocks are excluded when copying guest progress.", 14))
	else:
		col.add_child(hud.body_text("Both devices have changed. Choose one whole save; coins and unlocks are not added together. A local backup is kept before replacing progress.", 17))
		col.add_child(hud.label("THIS DEVICE", 25, hud.AMBER, true))
		col.add_child(hud.body_text(_summary(MobileCore.save.data), 19, hud.PAPER))
		_add(col, "KEEP DEVICE", func(): account.resolve("device"), true)
		var remote = account.conflict.remote
		if remote != null:
			col.add_child(hud.label("CLOUD", 25, hud.TEAL, true))
			col.add_child(hud.body_text(_summary(remote.payload), 19, hud.PAPER))
			col.add_child(hud.body_text(str(remote.updatedAt).replace("T", " "), 14))
			_add(col, "USE CLOUD", func(): account.resolve("cloud"))

func update() -> void:
	if hud == null or hud.current_page != "account": return
	if signature != state_key():
		hud.call_deferred("account_page")
		return
	if is_instance_valid(status_label): status_label.text = MobileCore.account.status
	for b in action_buttons:
		if is_instance_valid(b): b.disabled = MobileCore.account.busy
	if is_instance_valid(email_field): email_field.editable = not MobileCore.account.busy
	if is_instance_valid(password_field): password_field.editable = not MobileCore.account.busy
