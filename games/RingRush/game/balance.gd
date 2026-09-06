class_name RushBalance
extends RefCounted
const ROUND_SECONDS := 90.0
const MAX_ENEMIES := 48
const RING_LIMIT := 6.05
const PRODUCTS := {
	"gold_gloves":{"entitlement":"gold_gloves","type":"non_consumable"},
	"remove_ads":{"entitlement":"remove_ads","type":"non_consumable"},
	"coins_500":{"coins":500,"type":"consumable","title":"POCKET MONEY"},
	"coins_1500":{"coins":1500,"type":"consumable","title":"FIGHT PURSE"},
	"coins_4000":{"coins":4000,"type":"consumable","title":"CHAMPION'S VAULT"}
}
const REWARDS := {"training_coins":60,"revive":0,"victory_bonus":0}
const STAGES := [
	{"name":"THE UNDERGROUND","detail":"A floodlit boxing arena. Win your first belt.","boss":"IRON JACK","tint":Color("39d6c4"),"difficulty":1.0,"reward":100},
	{"name":"NEON SIEGE","detail":"Street crews surround you beneath the neon signs.","boss":"THE COLLECTOR","tint":Color("b397ff"),"difficulty":1.12,"reward":140},
	{"name":"SKYLINE ROOFTOP","detail":"Fight above the city on a rooftop helipad.","boss":"NIGHT HAWK","tint":Color("68cfff"),"difficulty":1.22,"reward":180},
	{"name":"IRON FOUNDRY","detail":"A furnace hall. Watch for the pressure vents.","boss":"THE FOREMAN","tint":Color("ff9960"),"difficulty":1.32,"reward":220},
	{"name":"DAWN TEMPLE","detail":"A mountain courtyard. The final master awaits.","boss":"THE SENTINEL","tint":Color("ffd277"),"difficulty":1.42,"reward":280},
 {"name":"THE RIFT","detail":"A sealed necropolis. The dead fight back.","boss":"THE BONE KING","tint":Color("b396ff"),"difficulty":1.3,"reward":240},
 {"name":"WILDWOOD","detail":"A sunlit forest clearing. Keep the wolf pack apart.","boss":"THE ALPHA","tint":Color("9bde78"),"difficulty":1.48,"reward":320},
 {"name":"HOLLOW GRAVEYARD","detail":"Haunted paths and restless spirits. Watch the homing wisps.","boss":"THE WAILING KING","tint":Color("7cddcf"),"difficulty":1.55,"reward":370},
 {"name":"ORBITAL STATION","detail":"A breached cargo deck. Break through the drone formation.","boss":"OVERSEER PRIME","tint":Color("78beff"),"difficulty":1.62,"reward":420}
]
const ABILITIES := [
	{"id": "power", "title": "Heavy hands", "detail": "+18% punch damage per rank.", "tag": "POWER", "max": 4, "icon": "fist"},
	{"id": "speed", "title": "Quick combo", "detail": "Punch 10% faster per rank.", "tag": "TEMPO", "max": 4, "icon": "bolt"},
	{"id": "range", "title": "Long reach", "detail": "+0.35 m to your punch reach.", "tag": "CONTROL", "max": 3, "icon": "target"},
	{"id": "heal", "title": "Second wind", "detail": "Recover 40 health immediately.", "tag": "RECOVERY", "max": 99, "icon": "heart"},
	{"id": "nova", "title": "Ring shock", "detail": "A damaging shockwave every 6s. Ranks add damage.", "tag": "AREA", "max": 3, "icon": "nova"},
	{"id": "feet", "title": "Light feet", "detail": "+6% movement speed per rank.", "tag": "MOBILITY", "max": 3, "icon": "dash"},
	{"id": "crit", "title": "Sweet spot", "detail": "+8% chance to land double damage.", "tag": "PRECISION", "max": 4, "icon": "target"},
	{"id": "armor", "title": "Iron guard", "detail": "Take 8% less damage per rank.", "tag": "DEFENSE", "max": 4, "icon": "shield"},
	{"id": "regen", "title": "Steady breath", "detail": "Recover 0.25 health every second per rank.", "tag": "RECOVERY", "max": 3, "icon": "heart"},
	{"id": "magnet", "title": "Prize fighter", "detail": "+1.2 m pickup attraction per rank.", "tag": "UTILITY", "max": 3, "icon": "magnet"},
	{"id": "burn", "title": "Hot knuckles", "detail": "Punches burn for 4 damage/s per rank for 3s.", "tag": "FIRE", "max": 3, "icon": "flame"},
	{"id": "frost", "title": "Cold snap", "detail": "Punches slow opponents by 35%. Ranks add duration.", "tag": "ICE", "max": 3, "icon": "snow"},
	{"id": "chain", "title": "Live wire", "detail": "Punches arc to one nearby opponent per rank.", "tag": "LIGHTNING", "max": 3, "icon": "bolt"},
	{"id": "leech", "title": "Fighting spirit", "detail": "Recover 0.35 health on every knockout per rank.", "tag": "SUSTAIN", "max": 3, "icon": "heart"},
	{"id": "orbit", "title": "Satellite fists", "detail": "Orbiting gloves damage nearby enemies.", "tag": "AREA", "max": 3, "icon": "orbit"},
	{"id": "dash", "title": "Slip & strike", "detail": "Dash cooldown reduced by 0.6s per rank.", "tag": "MOBILITY", "max": 3, "icon": "dash"},
	{"id": "fury", "title": "Main event", "detail": "Charge your ultimate 15% faster per rank.", "tag": "SPECIAL", "max": 3, "icon": "crown"},
	{"id": "vitality", "title": "Big heart", "detail": "+20 maximum health; recover 20 health.", "tag": "DEFENSE", "max": 3, "icon": "shield"},
	{"id":"echo_bolt","title":"Pulse engine","detail":"Fire an aimed bolt every 3.2s. Ranks add damage.","tag":"RANGED","max":3,"icon":"target"},
	{"id":"frost_fan","title":"Arctic volley","detail":"Three ice shards every 5s. Slow distant enemies.","tag":"RANGED","max":3,"icon":"snow"},
	{"id":"seeker","title":"Pocket rockets","detail":"A homing blast every 8s. Ranks strengthen it.","tag":"RANGED","max":3,"icon":"nova"},
	{"id":"ricochet","title":"Rebound spark","detail":"Direct hits fire a bolt at another foe. 2.5s cooldown.","tag":"RANGED","max":3,"icon":"bolt"},
	{"id":"longshot","title":"Distance fighter","detail":"+10% ranged damage beyond 3.5m per rank.","tag":"RANGED","max":3,"icon":"dash"}
]
const TRAINING := [
	{"id": "power", "title": "Power", "detail": "+0.8% base power per level", "icon": "fist"},
	{"id": "health", "title": "Conditioning", "detail": "+1.2% base health per level", "icon": "heart"},
	{"id": "charge", "title": "Composure", "detail": "+0.5% starting energy per level", "icon": "bolt"},
	{"id": "footwork", "title": "Footwork", "detail": "+0.5% base speed per level", "icon": "dash"},
	{"id": "mastery", "title": "Skill mastery", "detail": "Shorter skill cooldown", "icon": "crown"},
	{"id":"grit","title":"Resilience","detail":"Reduce incoming damage","icon":"shield"},
	{"id":"recovery","title":"Second wind","detail":"More health between waves","icon":"heart"},
	{"id":"fortune","title":"Fight purse","detail":"More coins from fights","icon":"coin"}
]

static func training_cost(level: int) -> int:
	return 80 + level * 50

static func ability(id: String) -> Dictionary:
	for entry in ABILITIES:
		if entry.id == id: return entry
	return {}

static func choices(ranks: Dictionary, wounded: bool, ranged_base:bool=false) -> Array:
	var available: Array = []
	for entry in ABILITIES:
		if entry.id=="longshot" and not ranged_base and not ["echo_bolt","frost_fan","seeker","ricochet"].any(func(id):return ranks.get(id,0)>0):continue
		if int(ranks.get(entry.id, 0)) < entry.max and (entry.id != "heal" or wounded): available.append(entry)
	available.shuffle()
	var offer:Array=available.slice(0,3)
	var ranged:Array=available.filter(func(entry):return entry.tag=="RANGED")
	if not ranged.is_empty() and not offer.any(func(entry):return entry.tag=="RANGED"):
		offer[-1]=ranged.pick_random()
	return offer
