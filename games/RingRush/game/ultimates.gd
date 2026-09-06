class_name RushUltimates
extends RefCounted
## E is tied to the fighter, independently of the equipped Q technique.
var remaining:=0.0
var tick:=0.0
var family:="rupture"
static func kind(character:String) -> String:
 if character in ["aegis","ion","onyx"]:return "siege"
 if character in ["zephyr","volt","sol"]:return "storm"
 return "rupture"
static func title(character:String) -> String:return {"rupture":"FAULTBREAKER","storm":"SKYFALL","siege":"SIEGE MODE"}[kind(character)]
static func description(character:String) -> String:return {"rupture":"Clear bullets · heavy ground impact · 4s empowered punches","storm":"Clear bullets · 3 targeted lightning strikes over 3s","siege":"Clear bullets · 4s faster robot weapons +20% damage"}[kind(character)]
func clear():remaining=0;tick=0;family="rupture"
func activate(game:Node3D):
 family=kind(game.player.character_id);remaining=3 if family=="storm" else 4;tick=0
 game.ranged_combat.clear(true)
 game.vfx.ring(game.player.position,Color("fff4ba"),7,.5,true)
 game.audio.play(load("res://assets/slam.wav"),.75)
 game.hud.toast(title(game.player.character_id))
 if family=="rupture":
  game.player.slam_time=.55;game.player.punch();game.vfx.quake(game.player.position,Color("ffb24a"),6)
  for actor in game.enemies.duplicate():
   if actor.position.distance_to(game.player.position)<6 and RushRangedCombat._wall_fraction(game.player.position,actor.position,game.stage,0)>=1:
    game._hit(actor,game.damage*3.5,false,true,false,"ultimate")
    if actor.active and actor.role!="boss":actor.frost=maxf(actor.frost,1.0)
  game.shake=.35;game.hit_stop=.065
func update(game:Node3D,delta:float):
 if remaining<=0:return
 remaining=maxf(0,remaining-delta)
 if remaining<=0:return
 tick-=delta
 if tick>0:return
 tick=1.0
 if family=="storm":
  var target:=RushRangedCombat.nearest(game,10)
  if target==null:return
  var at:Vector3=target.position
  game.vfx.beam(at+Vector3.UP*8,at,Color("c9eaff"));game.vfx.explosion(at,Color("9aafff"),2.5)
  for actor in game.enemies.duplicate():
   if actor.position.distance_to(at)<2.5 and RushRangedCombat._wall_fraction(at,actor.position,game.stage,0)>=1:game._hit(actor,game.damage*1.9,false,true,false,"ultimate")
 else:game.vfx.ring(game.player.position,Color("ffc46a") if family=="rupture" else Color("8be7ff"),1.25,.45,true)
func damage_scale() -> float:return (1.35 if family=="rupture" else 1.2) if remaining>0 and family!="storm" else 1.0
func weapon_cooldown() -> float:return .65 if remaining>0 and family=="siege" else 1.0
func snapshot() -> Dictionary:return {"remaining":remaining,"tick":tick,"family":family}
static func valid(data:Variant) -> bool:
 if not data is Dictionary or data.get("family") not in ["rupture","storm","siege"]:return false
 for id in ["remaining","tick"]:
  if not (data.get(id) is int or data.get(id) is float) or not is_finite(float(data[id])) or data[id]<0 or data[id]>(4 if id=="remaining" else 1):return false
 return true
func restore(data:Dictionary):remaining=data.remaining;tick=data.tick;family=data.family
