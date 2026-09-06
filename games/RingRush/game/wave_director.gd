class_name RushWaveDirector
extends RefCounted
## Explicit finite waves: quota -> clear -> recovery. Bosses count toward the quota.
const MODES := [
 {"id":"sprint","name":"QUICK FIGHT","waves":10,"icon":"fist","detail":"10 waves · Recovery between rounds"},
 {"id":"blitz","name":"BLITZ","waves":8,"icon":"bolt","detail":"8 waves · Fast spawns · Short breaks"},
 {"id":"survival30","name":"SURVIVAL 30","waves":30,"icon":"shield","detail":"30 waves · Build your survival kit"},
 {"id":"onslaught50","name":"ONSLAUGHT 50","waves":50,"icon":"flurry","detail":"50 waves · A long endurance fight"},
 {"id":"hell","name":"HELL MODE","waves":20,"icon":"skull","detail":"20 dense waves · No normal-wave healing"},
 {"id":"bossrush","name":"BOSS RUSH","waves":5,"icon":"crown","detail":"5 bosses · Dodge rushes, circles and slams"},
 {"id":"ladder","name":"WORLD LADDER","waves":40,"icon":"stairs","detail":"8 venues · 5 waves in each"},
 {"id":"classic","name":"90 SEC RUSH","waves":6,"icon":"timer","detail":"90 seconds · Beat the champion"},
 {"id":"rift","name":"THE RIFT","waves":12,"icon":"skull","detail":"12 waves · A secret creature encounter"}
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
	if mode_id=="rift":quota=mini(26,8+number)
	elif mode_id=="hell":quota=mini(36,12+number)
	elif mode_id=="blitz":quota=mini(24,6+number*2)
	elif mode_id=="bossrush":quota=1
	spawned = 0
	rest = 0
	clearing = false
func boss_wave() -> bool: return mode_id=="bossrush" or number % 5 == 0
func modifier() -> String:
	if boss_wave(): return "CHAMPION WAVE"
	if mode_id=="hell":return "NO MERCY"
	if mode_id=="blitz":return "KEEP MOVING"
	return ["CROWD CONTROL","RUNNER AMBUSH","HEAVY HANDS"][number % 3]
func advance() -> void:
	number += 1
	_prepare()

func spawn_delay() -> float:
	return .18 if mode_id=="hell" else (.22 if mode_id=="blitz" else maxf(.24,.65-number*.008))
func rest_duration() -> float:
	return .75 if mode_id=="hell" else (1.0 if mode_id=="blitz" else 2.4)
func recovery() -> float:
	return .08 if mode_id=="hell" and boss_wave() else (0.0 if mode_id=="hell" else (.15 if boss_wave() else .07))
