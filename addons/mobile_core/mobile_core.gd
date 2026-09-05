extends Node
## Reusable service root; game-specific catalogs are supplied by each game.
var save := CoreSaveStore.new()
var commerce := CoreCommerce.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("playtest"):
		save = CoreSaveStore.new("user://profile.playtest.json")
	elif OS.is_debug_build():
		save = CoreSaveStore.new("user://profile.debug.json")
	save.load_profile()
	if OS.has_feature("playtest") and not save.data.transactions.has("playtest-welcome-v1"):
		save.grant("playtest-welcome-v1",1200)
	add_child(commerce)

func configure_commerce(catalog: Dictionary, rewards: Dictionary, adapter: CoreCommerceProvider = null) -> void:
	if adapter == null:
		if (OS.is_debug_build() or OS.has_feature("playtest")) and ProjectSettings.get_setting("mobile_core/monetization/allow_debug_mock", false):
			adapter = preload("res://addons/mobile_core/monetization/mock_provider.gd").new()
		else:
			adapter = CoreCommerceProvider.new()
	commerce.configure(save, adapter, catalog, rewards)
