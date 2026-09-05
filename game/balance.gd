class_name RushBalance
extends RefCounted
const ROUND_SECONDS := 90.0
const MAX_ENEMIES := 48
const RING_LIMIT := 6.05
const PRODUCTS := {"gold_gloves": {"entitlement": "gold_gloves"}}
const REWARDS := {"training_coins": 60}
const STAGES := [
	{"name": "THE UNDERGROUND", "detail": "Find your feet. Claim your first belt.", "boss": "IRON JACK", "tint": Color("39d6c4"), "difficulty": 1.0, "reward": 100},
	{"name": "NEON DOCKS", "detail": "Faster feet. Harder fists. No easy corners.", "boss": "THE ANCHOR", "tint": Color("a493f2"), "difficulty": 1.25, "reward": 160},
	{"name": "GOLDEN CROWN", "detail": "The final circuit. Leave as champion.", "boss": "KING COBALT", "tint": Color("ffbe56"), "difficulty": 1.5, "reward": 240}
]
const ABILITIES := [
	{"id": "power", "title": "Heavy hands", "detail": "+25% punch damage per rank.", "tag": "POWER", "max": 4, "icon": "fist"},
	{"id": "speed", "title": "Quick combo", "detail": "Punch 15% faster per rank.", "tag": "TEMPO", "max": 4, "icon": "bolt"},
	{"id": "range", "title": "Long reach", "detail": "+0.35 m to your punch reach.", "tag": "CONTROL", "max": 3, "icon": "target"},
	{"id": "heal", "title": "Second wind", "detail": "Recover 40 health immediately.", "tag": "RECOVERY", "max": 99, "icon": "heart"},
	{"id": "nova", "title": "Ring shock", "detail": "A damaging shockwave every 6s. Ranks add damage.", "tag": "AREA", "max": 3, "icon": "nova"},
	{"id": "feet", "title": "Light feet", "detail": "+12% movement speed per rank.", "tag": "MOBILITY", "max": 3, "icon": "dash"},
	{"id": "crit", "title": "Sweet spot", "detail": "+12% chance to land double damage.", "tag": "PRECISION", "max": 4, "icon": "target"},
	{"id": "armor", "title": "Iron guard", "detail": "Take 10% less damage per rank.", "tag": "DEFENSE", "max": 4, "icon": "shield"},
	{"id": "regen", "title": "Steady breath", "detail": "Recover 1 health every second per rank.", "tag": "RECOVERY", "max": 3, "icon": "heart"},
	{"id": "magnet", "title": "Prize fighter", "detail": "+1.2 m pickup attraction per rank.", "tag": "UTILITY", "max": 3, "icon": "magnet"},
	{"id": "burn", "title": "Hot knuckles", "detail": "Punches burn for 4 damage/s per rank for 3s.", "tag": "FIRE", "max": 3, "icon": "flame"},
	{"id": "frost", "title": "Cold snap", "detail": "Punches slow opponents by 35%. Ranks add duration.", "tag": "ICE", "max": 3, "icon": "snow"},
	{"id": "chain", "title": "Live wire", "detail": "Punches arc to one nearby opponent per rank.", "tag": "LIGHTNING", "max": 3, "icon": "bolt"},
	{"id": "leech", "title": "Fighting spirit", "detail": "Recover 1 health on every knockout per rank.", "tag": "SUSTAIN", "max": 3, "icon": "heart"},
	{"id": "orbit", "title": "Satellite fists", "detail": "Orbiting gloves damage nearby enemies.", "tag": "AREA", "max": 3, "icon": "orbit"},
	{"id": "dash", "title": "Slip & strike", "detail": "Dash cooldown reduced by 0.6s per rank.", "tag": "MOBILITY", "max": 3, "icon": "dash"},
	{"id": "fury", "title": "Main event", "detail": "Charge your special 25% faster per rank.", "tag": "SPECIAL", "max": 3, "icon": "crown"},
	{"id": "vitality", "title": "Big heart", "detail": "+20 maximum health; recover 20 health.", "tag": "DEFENSE", "max": 3, "icon": "shield"}
]
const TRAINING := [
	{"id": "power", "title": "Power", "detail": "+3 starting punch damage", "icon": "fist"},
	{"id": "health", "title": "Conditioning", "detail": "+10 starting health", "icon": "heart"},
	{"id": "charge", "title": "Composure", "detail": "+10% starting special charge", "icon": "bolt"}
]

static func training_cost(level: int) -> int:
	return 80 + level * 50

static func ability(id: String) -> Dictionary:
	for entry in ABILITIES:
		if entry.id == id: return entry
	return {}

static func choices(ranks: Dictionary, wounded: bool) -> Array:
	var available: Array = []
	for entry in ABILITIES:
		if int(ranks.get(entry.id, 0)) < entry.max and (entry.id != "heal" or wounded): available.append(entry)
	available.shuffle()
	return available.slice(0, 3)
