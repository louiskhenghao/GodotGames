class_name RushRoster
extends RefCounted
## All prices and ownership decisions come from this catalog, never from UI input.
const CHARACTERS := [
	{"id":"atlas", "name":"ATLAS", "style":"THE PRIZEFIGHTER", "price":0, "hp":110.0,"damage":20.0,"speed":4.3,"tempo":0.62,"move":"barrage","color":Color("36d6c2"),"passive":"Balanced power. Starts with Iron guard." ,"rank":"armor"},
	{"id":"zephyr", "name":"ZEPHYR", "style":"THE CYCLONE", "price":180, "hp":85.0,"damage":15.0,"speed":5.1,"tempo":0.44,"move":"cyclone","color":Color("bba4ff"),"passive":"Fast combinations. Starts with Light feet.","rank":"feet"},
	{"id":"titan", "name":"TITAN", "style":"THE EARTHBREAKER", "price":300, "hp":155.0,"damage":29.0,"speed":3.6,"tempo":0.82,"move":"quake","color":Color("ffb45d"),"passive":"Heavy armor. Starts with two Iron guard ranks.","rank":"armor"},
	{"id":"volt", "name":"VOLT", "style":"THE LIVE WIRE", "price":420, "hp":95.0,"damage":17.0,"speed":4.8,"tempo":0.53,"move":"thunder","color":Color("6dbbff"),"passive":"Punches chain to a second opponent.","rank":"chain"},
	{"id":"raven", "name":"RAVEN", "style":"THE NIGHT STRIKER", "price":550, "hp":90.0,"damage":23.0,"speed":4.6,"tempo":0.60,"move":"dragon","color":Color("ff6979"),"passive":"Recover health on every knockout.","rank":"leech"},
	{"id":"sol", "name":"SOL", "style":"THE SUN CHAMPION", "price":700, "hp":105.0,"damage":19.0,"speed":4.4,"tempo":0.56,"move":"meteor","color":Color("ffd66e"),"passive":"Every punch ignites opponents.","rank":"burn"}
]
const MOVES := [
	{"id":"barrage","name":"HUNDRED HANDS","price":0,"cooldown":6.0,"detail":"A rapid six-punch combination that tracks the closest opponent.","icon":"fist"},
	{"id":"quake","name":"FAULT LINE","price":0,"cooldown":8.0,"detail":"Slam the floor. A wide shockwave staggers the crowd.","icon":"nova"},
	{"id":"cyclone","name":"CYCLONE FIST","price":160,"cooldown":9.0,"detail":"Spin for 1.4 seconds. Move through enemies and strike repeatedly.","icon":"orbit"},
	{"id":"thunder","name":"THUNDER STEP","price":220,"cooldown":7.0,"detail":"Lightning chains through up to eight nearby targets.","icon":"bolt"},
	{"id":"dragon","name":"RISING DRAGON","price":260,"cooldown":7.5,"detail":"Launch a close crowd with a devastating uppercut.","icon":"fist"},
	{"id":"meteor","name":"SOLAR WAVE","price":320,"cooldown":8.0,"detail":"Send a piercing fire wave in your facing direction.","icon":"flame"}
]
static func character(id: String) -> Dictionary:
	for entry in CHARACTERS:
		if entry.id == id: return entry
	return CHARACTERS[0]
static func move(id: String) -> Dictionary:
	for entry in MOVES:
		if entry.id == id: return entry
	return MOVES[0]
static func owned(store: CoreSaveStore, category: String, id: String) -> bool:
	if category == "character" and id == "atlas": return true
	if category == "move":
		if id == "quake": return true
		for c in CHARACTERS:
			if c.move == id and owned(store,"character",c.id): return true
	return store.data.progress.get("unlocks",{}).get(category+":"+id,false)
static func unlock(store: CoreSaveStore, category: String, id: String) -> bool:
	if category not in ["character","move"]: return false
	var catalog: Array = CHARACTERS if category == "character" else MOVES
	for entry in catalog:
		if entry.id != id: continue
		if owned(store,category,id): return true
		if store.data.coins < entry.price: return false
		var next := store.data.duplicate(true)
		next.coins -= entry.price
		if not next.progress.has("unlocks"): next.progress.unlocks = {}
		next.progress.unlocks[category+":"+id] = true
		return store.commit(next)
	return false
static func equip(store: CoreSaveStore, category: String, id: String) -> bool:
	if not owned(store,category,id): return false
	var next := store.data.duplicate(true)
	next.progress["selected_"+category] = id
	if category == "character": next.progress.selected_move = character(id).move
	return store.commit(next)
