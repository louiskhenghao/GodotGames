extends CoreCommerceProvider
## Development only. No SDKs, network requests, or money.
var fail_next := false

func _init() -> void:
	is_mock = true

func show_rewarded(request_id: String, _placement: String) -> void:
	await get_tree().create_timer(1.2).timeout
	var success := not fail_next
	fail_next = false
	ad_finished.emit(request_id, success, "Test reward completed." if success else "Test ad failed. No reward granted.")

func purchase(request_id: String, product: String) -> void:
	await get_tree().create_timer(0.6).timeout
	var success := not fail_next
	fail_next = false
	purchase_finished.emit(request_id, product, "mock:" + request_id, success, "Test purchase completed." if success else "Test purchase cancelled.")

func restore(request_id: String) -> void:
	await get_tree().create_timer(0.4).timeout
	restore_finished.emit(request_id, [], true, "Test store: local unlocks are already saved.")
