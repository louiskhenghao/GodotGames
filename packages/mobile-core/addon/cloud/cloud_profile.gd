class_name CoreCloudProfile
extends RefCounted
## Portable save envelope. Credentials and device-local ad promises never leave the device.
static func payload(data: Dictionary) -> Dictionary:
	var value := data.duplicate(true)
	value.erase("cloud")
	value.erase("reward_receipts")
	return value

static func digest(data: Dictionary) -> String:
	# Normalize JSON numbers: HTTP parsing turns integers into floats in Godot.
	var normalized = JSON.parse_string(JSON.stringify(payload(data)))
	return JSON.stringify(normalized).sha256_text()

static func valid(value: Variant) -> bool:
	if not value is Dictionary: return false
	var store := CoreSaveStore.new()
	return store._valid(value) and JSON.stringify(value).to_utf8_buffer().size() <= 500000

static func dirty(data: Dictionary) -> bool:
	return str(data.get("cloud", {}).get("digest", "")) != digest(data)

static func apply_ledger(data: Dictionary, entries: Array) -> Dictionary:
	var next := data.duplicate(true)
	var cursor := str(next.get("cloud", {}).get("purchase_cursor", "0"))
	var debt := int(next.get("iap_debt", 0))
	for entry in entries:
		if int(entry.sequence) <= int(cursor): continue
		if entry.get("currency") == "coins":
			var balance := int(next.coins) - debt + int(entry.amount)
			next.coins = maxi(0, balance)
			debt = maxi(0, -balance)
		cursor = str(entry.sequence)
	next.iap_debt = debt
	if not next.has("cloud"): next.cloud = {}
	next.cloud.purchase_cursor = cursor
	return next

static func imported_guest(data: Dictionary) -> Dictionary:
	var next := payload(data)
	# Simulated paid entitlements must never become real account purchases.
	next.entitlements = {}
	for key in next.transactions.keys():
		if str(key).begins_with("iap:"): next.transactions.erase(key)
	next.erase("iap_debt")
	return next
