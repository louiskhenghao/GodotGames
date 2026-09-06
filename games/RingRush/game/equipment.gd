class_name RushEquipment
extends RefCounted
const ITEMS:=[
 {"id":"sky_scout","name":"SKY SCOUT","slot":"air","model":"drone","price":650,"icon":"target","color":Color("83d7ff"),"trigger":"Every 6 direct hits","effect":"Fires 2 aimed bolts","cooldown":6.0,"charges":0},
 {"id":"medic","name":"MEDIC DRONE","slot":"air","model":"helper","price":1100,"icon":"heart","color":Color("8ae3ad"),"trigger":"Health below 40%","effect":"Heal 4% HP · max 7","cooldown":18.0,"charges":3},
 {"id":"arc_bee","name":"ARC BEE","slot":"air","model":"bee","price":1600,"icon":"snow","color":Color("ffd66e"),"trigger":"After you cast Q","effect":"Slows nearby foes · 1.4s","cooldown":12.0,"charges":0},
 {"id":"husky","name":"TRAIL WOLF","slot":"ground","model":"hound","price":450,"icon":"fist","color":Color("bfd2e7"),"trigger":"Every 8 direct hits","effect":"Bites a close enemy","cooldown":8.0,"charges":0},
 {"id":"fox","name":"SWIFT FOX","slot":"ground","model":"fox","price":900,"icon":"dash","color":Color("ffb481"),"trigger":"After you dodge","effect":"+8% speed · 2.5s","cooldown":10.0,"charges":0},
 {"id":"shiba","name":"RESCUE SHIBA","slot":"ground","model":"shiba","price":1300,"icon":"shield","color":Color("e6c08b"),"trigger":"Health below 30%","effect":"20% damage shield · 3s","cooldown":20.0,"charges":3}
]
static func item(id:String) -> Dictionary:
 for entry in ITEMS:
  if entry.id==id:return entry
 return {}
static func owned(store:CoreSaveStore,id:String) -> bool:return not item(id).is_empty() and store.data.progress.get("equipment_owned",{}).get(id,false)
static func selected(store:CoreSaveStore,slot:String) -> String:
 var id:String=store.data.progress.get("equipment_slots",{}).get(slot,"")
 return id if owned(store,id) and item(id).slot==slot else ""
static func buy(store:CoreSaveStore,id:String) -> bool:
 var entry:=item(id)
 if entry.is_empty():return false
 if owned(store,id):return true
 if store.data.coins<entry.price:return false
 var next:=store.data.duplicate(true);next.coins-=entry.price
 if not next.progress.has("equipment_owned"):next.progress.equipment_owned={}
 next.progress.equipment_owned[id]=true
 return store.commit(next)
static func equip(store:CoreSaveStore,slot:String,id:String) -> bool:
 if slot not in ["air","ground"]:return false
 if not id.is_empty() and (not owned(store,id) or item(id).slot!=slot):return false
 var next:=store.data.duplicate(true)
 if not next.progress.has("equipment_slots"):next.progress.equipment_slots={}
 next.progress.equipment_slots[slot]=id
 return store.commit(next)
