class_name RushEncounterRoster
extends RefCounted
## One content policy for finite waves, timed fights and legacy run restoration.
const FAMILIES:=[
 ["rookie","runner","brute","charger","guard"],
 ["rookie","runner","brute","spark","charger","guard"],
 ["runner","rookie","drone","guard","spark"],
 ["guard","brute","drone","spark","charger"],
 ["runner","guard","charger","spark","brute"],
 ["bone","revenant","hexer"],
 ["hound","spitter","stinger"],
 ["wisp","spitter"],
 ["drone","sentry"]
]
const LABELS:=["BOXERS · BRAWLERS","STREET CREWS","ROOFTOP SECURITY","INDUSTRIAL GUARDS","TEMPLE GUARDIANS","THE UNDEAD","WOLVES · SLIMES · STINGERS","SPIRITS · TOMB SLIMES","DRONES · SENTRIES"]
static func allowed(stage:int) -> Array:return FAMILIES[clampi(stage,0,FAMILIES.size()-1)]
static func pick(stage:int,wave:int,ordinal:int) -> String:
 var family:=allowed(stage)
 # Early rounds introduce only two roles. More attacks enter from wave 3 onward.
 var count:=mini(family.size(),2+maxi(0,wave-1)/2)
 return family[posmod(ordinal+wave-1,count)]
static func adapt(stage:int,role:String) -> String:
 if role=="boss" or role in allowed(stage):return role
 var preferred:String={"hound":"charger","drone":"runner","sentry":"guard","spitter":"brute","stinger":"runner","wisp":"runner"}.get(role,"")
 return preferred if preferred in allowed(stage) else pick(stage,5,role.hash())
static func boss_model(stage:int) -> String:return {6:"hound",7:"wisp",8:"sentry"}.get(stage,"")
