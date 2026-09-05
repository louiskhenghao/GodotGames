class_name CoreCommerce
extends Node
signal reward_ready(receipt_id: String)
signal completed(success: bool, message: String)
signal busy_changed(busy: bool)
var provider: CoreCommerceProvider
var store: CoreSaveStore
var products: Dictionary = {}
var placements: Dictionary = {}
var pending: Dictionary = {}
var timeout_seconds := 45.0

func configure(save: CoreSaveStore, adapter: CoreCommerceProvider, catalog: Dictionary, rewards: Dictionary) -> bool:
	if not pending.is_empty():return false
	if provider!=null:
		remove_child(provider);provider.queue_free()
	store = save
	provider = adapter
	products = catalog
	placements = rewards
	add_child(provider)
	provider.ad_finished.connect(_on_ad)
	provider.interstitial_finished.connect(_on_interstitial)
	provider.purchase_finished.connect(_on_purchase)
	provider.restore_finished.connect(_on_restore)
	return true

func _begin(kind: String, key: String) -> String:
	if not pending.is_empty():
		return ""
	var id := Crypto.new().generate_random_bytes(16).hex_encode()
	pending = {"id": id, "kind": kind, "key": key}
	busy_changed.emit(true)
	get_tree().create_timer(timeout_seconds).timeout.connect(func():
		if pending.get("id") == id:
			_finish(false, "Request timed out. Try again when connected."))
	return id

func reward(placement: String) -> void:
	if not placements.has(placement):
		return
	var id := _begin("ad", placement)
	if not id.is_empty():
		provider.show_rewarded(id, placement)

func buy(product: String) -> void:
	if not products.has(product):
		return
	var id := _begin("purchase", product)
	if not id.is_empty():
		provider.purchase(id, product)

func restore() -> void:
	var id := _begin("restore", "")
	if not id.is_empty():
		provider.restore(id)

func _matches(id: String, kind: String) -> bool:
	return pending.get("id") == id and pending.get("kind") == kind

func _on_ad(id: String, earned: bool, reason: String) -> void:
	if not _matches(id, "ad"):
		return
	if not earned:
		_finish(false, reason)
		return
	if pending.has("context"):
		var next:=store.data.duplicate(true)
		if not next.get("reward_receipts") is Dictionary:next.reward_receipts={}
		next.reward_receipts[id]={"placement":pending.key,"context":pending.context.duplicate(true)}
		var saved_receipt:=store.commit(next)
		_finish(saved_receipt,"Reward ready." if saved_receipt else "Unable to save reward. Free storage and retry.")
		if saved_receipt:reward_ready.emit(id)
		return
	var saved := store.grant("ad:" + id, int(placements[pending.key]))
	_finish(saved, "Reward saved." if saved else "Could not save reward.")

func _on_purchase(id: String, product: String, transaction: String, verified: bool, reason: String) -> void:
	if not products.has(product):
		return
	var matching: bool = _matches(id, "purchase") and pending.key == product
	if not verified or transaction.is_empty():
		if matching: _finish(false, reason)
		return
	# Verified native transactions may arrive after timeout or on app resume.
	# Reconcile them independently of a foreground request; never lose paid items.
	var entry: Dictionary = products[product]
	var already: bool = store.data.transactions.has("iap:" + transaction)
	var saved := already or store.grant("iap:" + transaction, int(entry.get("coins", 0)), entry.get("entitlement", ""))
	var message := "Purchase saved." if saved else "Could not save purchase. Restore or retry after resolving storage."
	if matching: _finish(saved, message)
	elif not already: completed.emit(saved, message)

func _on_restore(id: String, entitlements: Array, success: bool, reason: String) -> void:
	if not _matches(id, "restore"):
		return
	if not success:
		_finish(false, reason)
		return
	# Adapter may return only verified, non-consumable products from this catalog.
	var next := store.data.duplicate(true)
	for product in entitlements:
		if products.has(product) and products[product].has("entitlement"):
			next.entitlements[products[product].entitlement] = true
	var saved := store.commit(next)
	_finish(saved, reason if saved else "Could not save restored purchases.")

func _finish(success: bool, message: String) -> void:
	var request_id:String=pending.get("id","")
	pending.clear()
	provider.cancel(request_id)
	busy_changed.emit(false)
	completed.emit(success, message)

func reward_context(placement:String,context:Dictionary) -> void:
	if not placements.has(placement):return
	var id:=_begin("ad",placement)
	if id.is_empty():return
	pending.context=context.duplicate(true)
	provider.show_rewarded(id,placement)
func interstitial(placement:String) -> void:
	var id:=_begin("interstitial",placement)
	if not id.is_empty():provider.show_interstitial(id,placement)
func _on_interstitial(id:String,shown:bool,reason:String) -> void:
	if _matches(id,"interstitial"):_finish(shown,reason)
