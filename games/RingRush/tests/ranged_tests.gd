extends SceneTree
var checks:=0
var failures:=0
var game:Node3D
func _initialize():call_deferred("run")
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;push_error(message)
func fresh(character:String="atlas"):
 game._clear_combat();game.mode="playing";game.stage=0;game.wave=1
 game.player.set_character(character);game.player.position=Vector3.ZERO;game.player.rotation.y=0
 game.hp=1000;game.max_hp=1000;game.damage=20;game.reach=1.6;game.ranks={};game.invulnerable=0
 game.growth={"skill_level":1};game.attack_clock=0;game.run_mode="sprint"
func enemy(at:Vector3,kind:String="rookie") -> RushBoxer:
 var actor:RushBoxer=game._spawn(at,kind);actor.health=1000;actor.max_health=1000;return actor
func advance(duration:float):
 for i in ceili(duration/.02):game.ranged_combat.update(game,.02)
func active(hostile:bool=false) -> int:
 var count:=0
 for shot in game.ranged_combat.shots:
  if shot.active and shot.hostile==hostile:count+=1
 return count
func run():
 root.size=Vector2i(540,960)
 var core:=root.get_node("MobileCore");core.save=CoreSaveStore.new("user://ranged-tests.json")
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 game.set_process(false);game.set_physics_process(false);game.start_run();await process_frame
 fresh();var actor:=enemy(Vector3(0,0,-5))
 game.ranged_combat.fire(Vector3.UP*.8,Vector3.FORWARD,30,"bullet")
 game.ranged_combat.update(game,.4)
 check(actor.health==970,"swept fast projectile cannot tunnel through a target")
 check(active()==0,"impact consumes projectile exactly once")
 advance(.5);check(actor.health==970,"spent projectile cannot repeat its hit")
 fresh();game.ranged_combat.fire(Vector3(0,.8,-4),Vector3.BACK,10,"enemy",true)
 advance(.2);check(game.hp==1000,"enemy shot travels before dealing damage")
 game.player.position=Vector3(2,0,0);advance(.7)
 check(game.hp==1000,"player can sidestep a committed projectile")
 fresh();game.ranged_combat.fire(Vector3(0,.8,-3),Vector3.BACK,10,"enemy",true)
 advance(.6);check(game.hp==990,"hostile projectile hits at arrival")
 fresh();game.invulnerable=1;game.ranged_combat.fire(Vector3(0,.8,-2),Vector3.BACK,10,"enemy",true)
 advance(.5);check(game.hp==1000,"dodge protection rejects projectile damage")
 fresh();game.stage=1
 var obstacle:Vector3=RushArenaLayout.blockers(1)[0]
 var center:=Vector3(obstacle.x,0,obstacle.y)
 actor=enemy(center+Vector3.RIGHT*2)
 game.ranged_combat.fire(center+Vector3.LEFT*2+Vector3.UP*.8,Vector3.RIGHT,50,"missile",false,1.3)
 advance(.8);check(actor.health==1000 and active()==0,"obstacle stops a missile and shields its far side from blast")
 fresh();game.ranged_combat.fire(Vector3(7,.8,0),Vector3.RIGHT,10,"pulse")
 advance(.2);check(active()==0,"projectile ends at arena boundary")
 fresh()
 for i in 40:game.ranged_combat.fire(Vector3.UP,Vector3.FORWARD,1,"enemy",true)
 check(active(true)==RushRangedCombat.HOSTILE_LIMIT,"enemy projectile pressure has a hard cap")
 for i in 100:game.ranged_combat.fire(Vector3.UP,Vector3.FORWARD,1,"pulse")
 check(active()+active(true)==RushRangedCombat.CAPACITY,"all shots share a fixed capacity with no overwrite")
 game.ranged_combat.clear(true);check(active(true)==0 and active()>0,"wave clear removes only hostile shots")
 game._clear_combat();check(active()+active(true)==0,"exit resets every transient projectile")
 fresh();actor=enemy(Vector3(0,0,-5))
 game.ranged_combat.fire(Vector3.UP*.8,Vector3.FORWARD,10,"missile",false,1.3,false,actor)
 var generation:int=actor.generation;actor.configure("drone");actor.position=Vector3(5,0,0)
 advance(.2)
 check(actor.generation!=generation and absf(game.ranged_combat.shots[game.ranged_combat.cursor-1].velocity.x)<.001,"homing cannot track a recycled actor as the old target")
 for id in ["pulse","orb"]:
  fresh();actor=enemy(Vector3(0,0,-5));game.technique_id=id;game._cast_move(id,1);advance(.8)
  check(actor.health<1000,"human ranged skill reaches a distant enemy: "+id)
  check(game.records.get("casts_"+id,0)>0,"new skill use is recorded: "+id)
 check(RushRoster.owned(core.save,"move","pulse"),"every fighter owns the free ranged skill")
 for id in ["pulse","orb"]:
  fresh();actor=enemy(Vector3(0,0,-5));game._cast_move(id,1)
  var base:Dictionary=game.ranged_combat.shots.filter(func(p):return p.active)[0].duplicate()
  game.ranged_combat.clear();game.growth.skill_level=10;game._cast_move(id,1)
  var upgraded:Dictionary=game.ranged_combat.shots.filter(func(p):return p.active)[0]
  check(upgraded.damage>base.damage and upgraded.radius>base.radius,"skill upgrades increase ranged damage and hit size: "+id)
  check(upgraded.color!=base.color,"ascended ranged projectiles visibly change color: "+id)

 fresh();actor=enemy(Vector3(0,0,-5));game.ranged_combat.cast(game,"orb",1,1,Color.WHITE)
 var neighbor:=enemy(Vector3(.9,0,-5));advance(.8)
 check(actor.health<1000 and neighbor.health<1000,"orb explosion hits a nearby crowd")
 for id in ["aegis","ion","onyx"]:
  fresh(id);actor=enemy(Vector3(0,0,-4));game._attack();advance(.7)
  check(actor.health<1000,"robot weapon deals ranged damage: "+id)
  check(game.player.body.get_node_or_null("RangedWeapon")!=null,"robot has visible weapon geometry: "+id)
  check(game.attack_clock>0,"robot automatic fire respects a cooldown: "+id)
  if id=="onyx":check(actor.burn>0,"flamethrower ignites targets")
 fresh("onyx");actor=enemy(Vector3(3.5,0,0));var behind:=enemy(Vector3(-3.5,0,0));game._attack()
 check(actor.health<1000 and behind.health==1000,"flamethrower damages only its forward cone")
 fresh();actor=enemy(Vector3(0,0,-4));game._attack();advance(.8)
 check(actor.health==1000 and active()==0,"human basic attack remains a punch")
 for id in RushCreatureModel.TYPES:
  fresh();actor=enemy(Vector3(0,0,-3),id);actor.animate(.1,true)
  check(actor.is_nonhuman() and actor.creature_model.visible and not actor.crowd_mesh.visible,"non-humanoid silhouette replaces the human mesh: "+id)
  check(actor.creature_model.shell.mesh!=null and actor.creature_model.library.clips.Run.size()>1,"creature has authored mesh and shared movement poses: "+id)
  var old:Mesh=actor.creature_model.shell.mesh
  actor.begin_defeat(Vector3.FORWARD);actor.animate_defeat(1.2,0)
  check(actor.creature_model.shell.material_override.albedo_color.a<1,"creature falls and fades: "+id)
  actor.configure("rookie");check(actor.crowd_mesh.visible and not actor.creature_model.visible,"pooled creature returns cleanly to human: "+id)
  actor.configure(id);check(actor.creature_model.shell.mesh==actor.creature_model.library.clips.Idle[0] and actor.creature_model.shell.material_override.albedo_color.a==1,"creature mesh is reused and opacity restored: "+id)
  if id!="hound":
   actor.attack_target=game.player.position;actor.windup=.01;game._update_enemy(actor,.02)
   check(active(true)==(3 if id=="drone" else (2 if id=="sentry" else 1)),"ranged creature fires its own pattern: "+id)
   check(game.hp==1000,"windup completion does not deal instant invisible damage: "+id)
  else:
   actor.attack_target=game.player.position;actor.windup=.01;game._update_enemy(actor,.02)
   check(actor.rush_time>0,"hound commits to a charge instead of firing")
 fresh()
 for i in 4:enemy(Vector3(i,0,-3),RushCreatureModel.TYPES[i])
 game.technique_id="orb"
 var snapshot:Dictionary=JSON.parse_string(JSON.stringify(RushRunSnapshot.capture(game)))
 check(RushRunSnapshot.valid(snapshot),"JSON snapshot accepts new enemies and ranged skills")
 game.ranged_combat.fire(Vector3.UP,Vector3.FORWARD,1,"enemy",true)
 RushRunSnapshot.restore(game,snapshot)
 check(active(true)==0 and game.enemies.size()==4,"resume rebuilds enemies and clears unpersisted shots")
 game.vfx.clear();game.vfx.enabled=false
 game.vfx.projectile(Vector3.UP,Vector3.FORWARD,Color.RED,"enemy",.3)
 check(Array(game.vfx.projectile_lives).any(func(life):return life>0),"essential projectile remains visible with effects off")
 game.vfx.quake(Vector3.ZERO,Color.ORANGE,4)
 check(game.vfx.spectacle.groups.rock.slots.all(func(p):return p.life==0),"effects off disables optional debris")
 game.vfx.enabled=true;game.vfx.detail=0;game.vfx.clear();game.vfx.quake(Vector3.ZERO,Color.ORANGE,4)
 var low_count:int=game.vfx.spectacle.groups.rock.slots.filter(func(p):return p.life>0).size()
 game.vfx.detail=1;game.vfx.clear();game.vfx.quake(Vector3.ZERO,Color.ORANGE,4)
 check(game.vfx.spectacle.groups.rock.slots.filter(func(p):return p.life>0).size()>low_count,"low quality reduces decorative particles")
 for i in 20:game.vfx.explosion(Vector3(i,0,0),Color.ORANGE,3)
 check(game.vfx.spectacle.groups.rock.slots.size()==96 and game.vfx.spectacle.groups.dust.slots.size()==64,"overlapping blasts never grow the instance pools")
 game.vfx.clear();check(game.vfx.spectacle.groups.dust.slots.all(func(p):return p.life==0),"clear removes all spectacle particles")
 for size in [Vector2i(320,568),Vector2i(540,960),Vector2i(768,1024)]:
  root.size=size;game.go_home();game.hud.moves()
  for i in 4:await process_frame
  var scroll:ScrollContainer=game.hud.screen.find_child("SkillsScroll",true,false)
  var actions:Control=game.hud.screen.find_child("SkillActions",true,false)
  check(scroll.get_global_rect().end.y+10<=actions.get_global_rect().position.y,"eight-skill content cannot overlap fixed actions: "+str(size))
  check(scroll.clip_contents and scroll.get_child(0).find_children("Move_*","",true,false).size()==8,"every skill remains reachable in a clipped scroll area: "+str(size))
 game.queue_free();await process_frame;await create_timer(.3).timeout
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://ranged-tests.json"+suffix)
 print("RANGED COMBAT: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
