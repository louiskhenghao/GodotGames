class_name RushSupportCombat
extends Node3D
## Two frozen loadout slots. Triggers are bounded; healing charges survive reloads.
var slots:Dictionary={}
var models:Dictionary={}
var pivots:Dictionary={}
var speed_time:=0.0
var shield_time:=0.0
var clock:=0.0
func _ready():
 for slot in ["air","ground"]:
  var pivot:=Node3D.new();add_child(pivot);pivots[slot]=pivot
  var model:=RushCreatureModel.new();model.scale=Vector3.ONE*.6;pivot.add_child(model);model.visible=false;models[slot]=model
func clear():
 slots.clear();speed_time=0;shield_time=0;clock=0
 for model in models.values():model.visible=false
func begin(store:CoreSaveStore):
 clear()
 for slot in ["air","ground"]:
  var id:=RushEquipment.selected(store,slot)
  if id.is_empty():continue
  var entry:=RushEquipment.item(id)
  slots[slot]={"id":id,"cooldown":3.0,"hits":0,"charges":entry.charges,"attack_time":0.0}
  models[slot].configure(entry.model);models[slot].visible=true
func update(game:Node3D,delta:float):
 clock+=delta;speed_time=maxf(0,speed_time-delta);shield_time=maxf(0,shield_time-delta)
 for slot in slots:
  var state:Dictionary=slots[slot];var model:RushCreatureModel=models[slot];var pivot:Node3D=pivots[slot]
  state.cooldown=maxf(0,state.cooldown-delta);state.attack_time=maxf(0,state.attack_time-delta)
  var offset:=Vector3(-.95,1.1,.75) if slot=="air" else Vector3(1.0,0,.9)
  var destination:Vector3=game.player.position+offset
  if slot=="ground":destination=RushArenaLayout.constrain(destination,game.stage,.2)
  var moving:bool=pivot.position.distance_to(destination)>.08
  pivot.position=pivot.position.lerp(destination,minf(1,delta*7))
  var direction:Vector3=destination-pivot.position
  if moving:model.rotation.y=atan2(direction.x,direction.z)
  model.animate(clock,moving,0,state.attack_time)
  if state.id=="medic" and game.hp<game.max_hp*.4 and state.charges>0 and state.cooldown<=0:
   game.hp=minf(game.max_hp,game.hp+minf(7,game.max_hp*.04));state.charges-=1;activate(game,slot)
   game.vfx.ring(game.player.position,Color("8af3b3"),1.4,.5,true)
  elif state.id=="shiba" and game.hp<game.max_hp*.3 and state.charges>0 and state.cooldown<=0:
   shield_time=3;state.charges-=1;activate(game,slot)
   game.vfx.ring(game.player.position,Color("80cfff"),1.2,.5,true)
  elif state.id in ["sky_scout","husky"] and state.hits>=(6 if state.id=="sky_scout" else 8) and state.cooldown<=0:
   var target:=RushRangedCombat.nearest(game,7 if slot=="air" else 3)
   if target==null:continue
   state.hits=0;activate(game,slot)
   var origin:Vector3=pivot.position+Vector3.UP*.7
   var aim:Vector3=(target.position+Vector3.UP*.8-origin).normalized()
   model.rotation.y=atan2(aim.x,aim.z)
   if slot=="air":
    for angle in [-.05,.05]:game.ranged_combat.fire(origin,aim.rotated(Vector3.UP,angle),game.damage*.3,"pulse",false,0,false,null,Color("87e3ff"),1,"support")
   else:
    game.vfx.strike(target.position,aim,Color("bddcff"));game._hit(target,game.damage*.65,false,false,false,"support")
func on_hit():
 for state in slots.values():
  if state.id in ["sky_scout","husky"]:state.hits=mini(8,int(state.hits)+1)
func on_dodge(game:Node3D):
 for slot in slots:
  var state:Dictionary=slots[slot]
  if state.id=="fox" and state.cooldown<=0:
   speed_time=2.5;activate(game,slot);game.vfx.ring(game.player.position,Color("ffcf86"),1.3,.4,true)
func on_skill(game:Node3D):
 for slot in slots:
  var state:Dictionary=slots[slot]
  if state.id=="arc_bee" and state.cooldown<=0:
   var target:=RushRangedCombat.nearest(game,6)
   if target==null:return
   for actor in game.enemies:
    if actor.position.distance_to(target.position)<2:actor.frost=maxf(actor.frost,1.4)
   game.vfx.cyclone(target.position,Color("b4efff"),2);activate(game,slot)
func activate(game:Node3D,slot:String):
 var state:Dictionary=slots[slot];state.cooldown=RushEquipment.item(state.id).cooldown;state.attack_time=.5
 game.record_action("support_triggers")
func snapshot() -> Dictionary:return {"slots":slots.duplicate(true),"speed_time":speed_time,"shield_time":shield_time}
static func valid(data:Variant) -> bool:
 if not data is Dictionary or not data.get("slots") is Dictionary or data.slots.size()>2:return false
 for key in ["speed_time","shield_time"]:
  if not (data.get(key) is float or data.get(key) is int) or not is_finite(float(data[key])) or data[key]<0 or data[key]>3:return false
 for slot in data.slots:
  if slot not in ["air","ground"] or not data.slots[slot] is Dictionary:return false
  var state:Dictionary=data.slots[slot];var item:=RushEquipment.item(str(state.get("id","")))
  if item.is_empty() or item.slot!=slot:return false
  for key in ["cooldown","hits","charges","attack_time"]:
   if not (state.get(key) is float or state.get(key) is int) or not is_finite(float(state[key])) or state[key]<0:return false
  if state.hits!=floorf(state.hits) or state.charges!=floorf(state.charges):return false
  if state.cooldown>item.cooldown or state.hits>8 or state.charges>item.charges or state.attack_time>.5:return false
 return true
func restore(data:Dictionary,at:Vector3):
 clear();slots=data.slots.duplicate(true);speed_time=data.speed_time;shield_time=data.shield_time
 for slot in slots:
  models[slot].configure(RushEquipment.item(slots[slot].id).model);models[slot].visible=true;pivots[slot].position=at
