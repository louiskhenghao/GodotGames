class_name RushWaveDirector
extends RefCounted
## Explicit finite waves: quota -> clear -> recovery. Bosses count toward the quota.
const MODES := [
	{"id":"sprint","name":"QUICK FIGHT","waves":10,"detail":"10 waves. A short fight with a boss every five waves."},
	{"id":"survival30","name":"SURVIVAL 30","waves":30,"detail":"30 waves. Build powerful combinations and outlast the crowd."},
	{"id":"onslaught50","name":"ONSLAUGHT 50","waves":50,"detail":"50 waves. The longest test; stronger elite formations."},
	{"id":"ladder","name":"WORLD LADDER","waves":25,"detail":"Five venues, five bosses. Climb to a new arena every five waves."},
	{"id":"classic","name":"90-SECOND RUSH","waves":6,"detail":"The original timed circuit. Survive 90 seconds and beat its champion."}
]
var number := 1
var target := 10
var quota := 5
var spawned := 0
var rest := 0.0
var clearing := false
var mode_id := "sprint"
static func mode_info(id: String) -> Dictionary:
	for m in MODES:
		if m.id == id: return m
	return MODES[0]
func begin(id: String) -> void:
	mode_id = mode_info(id).id
	target = mode_info(id).waves
	number = 1
	_prepare()
func _prepare() -> void:
	quota = mini(22, 4 + number / 2 + (3 if number % 3 == 0 else 0))
	spawned = 0
	rest = 0
	clearing = false
func boss_wave() -> bool: return number % 5 == 0
func modifier() -> String:
	if boss_wave(): return "CHAMPION WAVE"
	return ["CROWD CONTROL","RUNNER AMBUSH","HEAVY HANDS"][number % 3]
func advance() -> void:
	number += 1
	_prepare()
