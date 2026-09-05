class_name CoreCommerceProvider
extends Node
## Native adapters implement these methods; emit completion only after SDK confirmation.
## IAP adapters validate receipts server-side, then emit a stable store transaction ID.
signal ad_finished(request_id: String, earned: bool, reason: String)
signal interstitial_finished(request_id: String, shown: bool, reason: String)
signal purchase_finished(request_id: String, product: String, transaction: String, verified: bool, reason: String)
signal restore_finished(request_id: String, entitlements: Array, success: bool, reason: String)
var is_mock := false

func show_rewarded(request_id: String, _placement: String) -> void:
	ad_finished.emit(request_id, false, "Ads are not configured in this build.")

func purchase(request_id: String, product: String) -> void:
	purchase_finished.emit(request_id, product, "", false, "Store is not configured in this build.")

func restore(request_id: String) -> void:
	restore_finished.emit(request_id, [], false, "Store is not configured in this build.")

func show_interstitial(request_id: String, _placement: String) -> void:
	interstitial_finished.emit(request_id,false,"Ads are not configured in this build.")
func set_banner(_visible: bool) -> void:
	pass
func cancel(_request_id: String) -> void:
	pass
