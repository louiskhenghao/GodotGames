class_name RushRangedCombat
extends RefCounted
## Bounded gameplay projectiles. Rendering stays in mobile-core; hits use swept segments.
const CAPACITY:=96
const HOSTILE_LIMIT:=28
var shots:Array[Dictionary]=[]
var cursor:=0
func _init():
 for i in CAPACITY:shots.append({"active":false})
func clear(hostile_only:bool=false):
 for shot in shots:
  if not hostile_only or shot.get("hostile",false):shot.active=false
func fire(at:Vector3,direction:Vector3,damage:float,kind:String,hostile:bool=false,splash:float=0,skill:bool=false,target:Node3D=null,tint:Color=Color.TRANSPARENT,size_scale:float=1,source:String="ranged") -> bool:
 if direction.length_squared()<.001:return false
 if hostile:
  var count:=0
  for shot in shots:
   if shot.active and shot.hostile:count+=1
  if count>=HOSTILE_LIMIT:return false
 var index:=-1
 for i in CAPACITY:
  var candidate:=(cursor+i)%CAPACITY
  if not shots[candidate].active:index=candidate;break
 if index<0:return false
 cursor=(index+1)%CAPACITY
 var speed:float={"bullet":19.0,"ice":12.0,"pulse":17.0,"missile":8.5,"orb":10.0,"acid":5.0,"enemy":6.5,"seeker":5.4}.get(kind,10.0)
 var color:Color={"bullet":Color("fff3a0"),"ice":Color("a3e8ff"),"pulse":Color("65eaff"),"missile":Color("ffb67d"),"orb":Color("d39aff"),"acid":Color("b8ee58"),"enemy":Color("ff7467"),"seeker":Color("e391ff")}[kind]
 if tint.a>0:color=tint
 shots[index]={"active":true,"source":source,"ignored":null,"ignored_generation":-1,"origin":at,"at":at,"velocity":direction.normalized()*speed,"life":2.1,"age":0.0,"fx_clock":0.0,"damage":damage,"kind":kind,"hostile":hostile,"splash":splash,"skill":skill,"target":weakref(target) if target!=null else null,"generation":target.generation if target!=null else -1,"color":color,"radius":(.18 if kind=="bullet" else .32)*clampf(size_scale,1,1.8)}
 return true
func update(game:Node3D,delta:float):
 for shot in shots:
  if not shot.active:continue
  shot.life-=delta;shot.age+=delta
  if shot.life<=0:shot.active=false;continue
  if shot.target!=null and shot.age<.8:
   var target=shot.target.get_ref()
   if target!=null and target.active and target.generation==shot.generation:
    var seek:Vector3=target.position+Vector3.UP*.8-shot.at
    shot.velocity=shot.velocity.lerp(seek.normalized()*shot.velocity.length(),minf(1,delta*3.2))
  var before:Vector3=shot.at
  var after:Vector3=before+shot.velocity*delta
  var limit:float=_wall_fraction(before,after,game.stage,shot.radius)
  var victim:Node3D=null
  if shot.hostile:
   var t:float=_hit_fraction(before,after,game.player.position,.43+shot.radius)
   if t>=0 and t<limit:limit=t;victim=game.player
  else:
   for actor in game.enemies:
    if not actor.active:continue
    if shot.ignored!=null and shot.ignored.get_ref()==actor and shot.ignored_generation==actor.generation:continue
    var t:float=_hit_fraction(before,after,actor.position,.4*actor.scale.x+shot.radius)
    if t>=0 and t<limit:limit=t;victim=actor
  shot.at=before.lerp(after,limit)
  shot.fx_clock-=delta
  game.vfx.projectile(shot.at,shot.velocity.normalized(),shot.color,shot.kind,shot.radius,shot.fx_clock<=0)
  if shot.fx_clock<=0:shot.fx_clock=.065
  if victim!=null or limit<1:
   shot.active=false
   if shot.splash>0:
    game.vfx.explosion(shot.at,shot.color,shot.splash)
    game.audio.play(load("res://assets/slam.wav"),1.2 if shot.hostile else .9)
    if shot.hostile:
     if game.player.position.distance_to(Vector3(shot.at.x,0,shot.at.z))<shot.splash and _wall_fraction(shot.at,game.player.position,game.stage,0)>=1:game._take_damage(shot.damage)
    else:
     for actor in game.enemies.duplicate():
      if actor.position.distance_to(Vector3(shot.at.x,0,shot.at.z))<shot.splash and _wall_fraction(shot.at,actor.position,game.stage,0)>=1:
       _deliver(game,actor,shot,true)
   elif victim!=null:
    if shot.hostile:game._take_damage(shot.damage)
    else:_deliver(game,victim,shot,false)
    game.vfx.hit_flash(shot.at,shot.color)
   else:game.vfx.wall_impact(shot.at,shot.color)
func _deliver(game:Node3D,actor:Node3D,shot:Dictionary,critical:bool):
 var amount:float=shot.damage
 if shot.source!="support" and shot.origin.distance_to(actor.position)>3.5:amount*=1+.1*game.rank_of("longshot")
 if shot.source=="ranged":amount*=game.ultimate.damage_scale()
 if shot.kind=="ice":actor.frost=maxf(actor.frost,1.2+.4*game.rank_of("frost_fan"))
 game._hit(actor,amount,not shot.skill and shot.source=="ranged",critical,shot.skill,shot.source)
func auto_fire(game:Node3D) -> bool:
 var fighter:=RushRoster.character(game.player.character_id)
 var weapon:String=fighter.get("weapon","")
 if weapon.is_empty():return false
 var target:Node3D=nearest(game,8.5 if weapon!="flamethrower" else 5.4)
 if target==null or target.position.distance_to(game.player.position)<=game.reach:return false
 var direction:Vector3=(target.position-game.player.position).normalized()
 game.player.face(direction);game.player.punch()
 var origin:Vector3=game.player.position+Vector3.UP*.95+direction*.65
 match weapon:
  "minigun":
   game.attack_clock=.18
   for side in [-1,1]:fire(origin,(direction+Vector3(direction.z,0,-direction.x)*side*.022),game.damage*.17,"bullet")
   game.vfx.muzzle(origin,Color("ffd56c"),.55)
   game.audio.play(load("res://assets/minigun.wav"),randf_range(.94,1.08))
  "missiles":
   game.attack_clock=1.35
   for side in [-1,1]:fire(origin+Vector3(direction.z,0,-direction.x)*side*.27,direction,game.damage*.82,"missile",false,1.3,false,target)
   game.vfx.muzzle(origin,Color("9ef4da"),.8)
   game.audio.play(load("res://assets/missile_launch.wav"),1.0)
  "flamethrower":
   game.attack_clock=.16
   var visible_length:float=5.4*_wall_fraction(origin,origin+direction*5.4,game.stage,0)
   game.vfx.flame_jet(origin,direction,visible_length,Color("ff9e4d"))
   for actor in game.enemies.duplicate():
    var offset:Vector3=actor.position-game.player.position
    if offset.length()<5.4 and offset.normalized().dot(direction)>.84 and _wall_fraction(origin,actor.position,game.stage,0)>=1:
     game._hit(actor,game.damage*.14*game.ultimate.damage_scale(),true,false,false,"ranged")
     actor.burn=maxf(actor.burn,1.5);actor.burn_damage=maxf(actor.burn_damage,game.damage*.2)
   if int(game.elapsed*6)%3==0:game.audio.play(load("res://assets/flamethrower.wav"),.92)
 game.attack_clock*=game.ultimate.weapon_cooldown()
 return true
func cast(game:Node3D,id:String,strength:float,scale:float,color:Color):
 var target:=nearest(game,11)
 var direction:Vector3=(target.position-game.player.position).normalized() if target!=null else -game.player.basis.z
 game.player.face(direction)
 var origin:Vector3=game.player.position+Vector3.UP*.8+direction*.4
 if id=="pulse":
  for angle in [-.12,0,.12]:fire(origin,direction.rotated(Vector3.UP,angle),game.damage*1.05*strength,"pulse",false,0,true,null,color,scale)
 else:fire(origin,direction,game.damage*3.0*strength,"orb",false,2.3*scale,true,target,color,scale)
 game.vfx.muzzle(origin,color,1.15)
 game.audio.play(load("res://assets/energy_bolt.wav"),1.0 if id=="pulse" else .7)
static func nearest(game:Node3D,range_limit:float) -> Node3D:
 var best:Node3D=null;var distance:=range_limit
 for actor in game.enemies:
  var d:float=actor.position.distance_to(game.player.position)
  if d<distance and _wall_fraction(game.player.position,actor.position,game.stage,0)>=1:best=actor;distance=d
 return best
static func _hit_fraction(from:Vector3,to:Vector3,point:Vector3,radius:float) -> float:
 var a:=Vector2(from.x-point.x,from.z-point.z);var d:=Vector2(to.x-from.x,to.z-from.z)
 var c:=a.length_squared()-radius*radius
 if c<=0:return 0
 if d.length_squared()<.000001:return -1
 var b:=a.dot(d);var discriminant:=b*b-d.length_squared()*c
 if discriminant<0:return -1
 var t:=(-b-sqrt(discriminant))/d.length_squared()
 return t if t>=0 and t<=1 else -1
static func _wall_fraction(from:Vector3,to:Vector3,stage:int,radius:float) -> float:
 var limit:=1.0
 for obstacle in RushArenaLayout.blockers(stage):
  var t:=_hit_fraction(from,to,Vector3(obstacle.x,0,obstacle.y),obstacle.z+radius)
  if t>=0:limit=minf(limit,t)
 var a:=Vector2(from.x,from.z);var b:=Vector2(to.x,to.z);var polygon:=RushArenaLayout.polygon(stage)
 for i in polygon.size():
  var hit=Geometry2D.segment_intersects_segment(a,b,polygon[i],polygon[(i+1)%polygon.size()])
  if hit!=null and a.distance_to(b)>.0001:limit=minf(limit,a.distance_to(hit)/a.distance_to(b))
 return limit
