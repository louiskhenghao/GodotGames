class_name RushRunArsenal
extends RefCounted
## Independent passive timers; their hits never recursively trigger direct-hit skills.
const PERIODS={"echo_bolt":3.2,"frost_fan":5.0,"seeker":8.0,"ricochet":2.5}
var timers:Dictionary={}
func clear():timers={"echo_bolt":2.0,"frost_fan":3.0,"seeker":4.0,"ricochet":0.0}
func _init():clear()
func update(game:Node3D,delta:float):
 for id in timers:timers[id]=maxf(0,timers[id]-delta)
 for id in ["echo_bolt","frost_fan","seeker"]:
  var rank:int=game.rank_of(id)
  if rank<=0 or timers[id]>0:continue
  var target:=RushRangedCombat.nearest(game,10)
  if target==null:continue
  timers[id]=PERIODS[id]
  var at:Vector3=game.player.position+Vector3.UP*.85
  var aim:Vector3=(target.position+Vector3.UP*.8-at).normalized()
  match id:
   "echo_bolt":game.ranged_combat.fire(at,aim,game.damage*(.55+.2*rank),"pulse",false,0,false,null,Color.TRANSPARENT,1,"passive")
   "frost_fan":
    for angle in [-.18,0,.18]:game.ranged_combat.fire(at,aim.rotated(Vector3.UP,angle),game.damage*(.25+.12*rank),"ice",false,0,false,null,Color.TRANSPARENT,1,"passive")
   "seeker":game.ranged_combat.fire(at,aim,game.damage*(.6+.2*rank),"missile",false,1+.15*rank,false,target,Color.TRANSPARENT,1,"passive")
  game.vfx.muzzle(at,Color("a4e9ff"),.65)
func on_hit(game:Node3D,victim:Node3D):
 if game.rank_of("ricochet")<=0 or timers.ricochet>0:return
 for actor in game.enemies:
  if actor==victim or not actor.active or actor.position.distance_to(victim.position)>4:continue
  if RushRangedCombat._wall_fraction(victim.position,actor.position,game.stage,0)<1:continue
  timers.ricochet=PERIODS.ricochet
  var at:Vector3=victim.position+Vector3.UP*.8
  if game.ranged_combat.fire(at,(actor.position-victim.position).normalized(),game.damage*(.35+.15*game.rank_of("ricochet")),"pulse",false,0,false,null,Color("d4a4ff"),1,"passive"):
   var shot:Dictionary=game.ranged_combat.shots[posmod(game.ranged_combat.cursor-1,RushRangedCombat.CAPACITY)]
   shot.ignored=weakref(victim);shot.ignored_generation=victim.generation
  break
static func valid(data:Variant) -> bool:
 if not data is Dictionary or data.size()!=PERIODS.size():return false
 for id in PERIODS:
  if not (data.get(id) is int or data.get(id) is float) or not is_finite(float(data[id])) or data[id]<0 or data[id]>PERIODS[id]:return false
 return true
