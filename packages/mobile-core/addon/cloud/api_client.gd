class_name CoreApiClient
extends Node
## Bearer credentials live in memory only, never in game saves or browser storage.
var base_url := ""
var access_token := ""
var refresh_token := ""
var transport: Callable # Test transport; production uses HTTPRequest.

func configure(url: String) -> void:
	base_url = url.trim_suffix("/")
	var local := base_url.begins_with("http://127.0.0.1:") or base_url.begins_with("http://localhost:")
	if not base_url.begins_with("https://") and not (local and (OS.is_debug_build() or OS.has_feature("playtest"))):
		base_url = ""

func forget() -> void:
	access_token = ""
	refresh_token = ""

func accept_tokens(body: Dictionary) -> void:
	access_token = str(body.get("accessToken", ""))
	refresh_token = str(body.get("refreshToken", ""))

func call_api(method: int, path: String, body: Dictionary = {}, authorized := true) -> Dictionary:
	if base_url.is_empty(): return {"ok": false, "error": "NOT_CONFIGURED", "status": 0}
	var result := await _send(method, path, body, access_token if authorized else "")
	if authorized and result.status == 401 and not refresh_token.is_empty():
		var refreshed := await _send(HTTPClient.METHOD_POST, "/v1/auth/refresh", {"refreshToken": refresh_token}, "")
		# Never retry a refresh after an uncertain response: the server may have rotated it.
		if not refreshed.ok:
			forget()
			return {"ok": false, "error": "SIGN_IN_REQUIRED", "status": 401}
		accept_tokens(refreshed.body)
		result = await _send(method, path, body, access_token)
	if authorized and result.status == 401: forget()
	return result

func _send(method: int, path: String, body: Dictionary, bearer: String) -> Dictionary:
	if transport.is_valid(): return await transport.call(method, path, body, bearer)
	var http := HTTPRequest.new()
	http.timeout = 8.0
	http.body_size_limit = 700000
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if not bearer.is_empty(): headers.append("Authorization: Bearer " + bearer)
	var error := http.request(base_url + path, headers, method, "" if method == HTTPClient.METHOD_GET else JSON.stringify(body))
	if error != OK:
		http.queue_free()
		return {"ok": false, "error": "OFFLINE", "status": 0}
	var reply: Array = await http.request_completed
	http.queue_free()
	if reply[0] != HTTPRequest.RESULT_SUCCESS: return {"ok": false, "error": "OFFLINE", "status": 0}
	var status := int(reply[1])
	var parsed: Variant = {}
	if status != 204:
		var json := JSON.new()
		if json.parse(reply[3].get_string_from_utf8()) != OK: return {"ok": false, "error": "INVALID_RESPONSE", "status": status}
		parsed = json.data
	if not parsed is Dictionary: return {"ok": false, "error": "INVALID_RESPONSE", "status": status}
	return {"ok": status >= 200 and status < 300, "status": status, "body": parsed, "error": str(parsed.get("error", ""))}
