extends SceneTree
const FOLDER="res://docs/ranged-preview/"
var game:Node3D
func _initialize():call_deferred("run")
func snap(name:String):
 RenderingServer.force_draw();root.get_texture().get_image().save_png(FOLDER+name+".png")
func tick(seconds:float,projectiles:bool=false):
 for i in ceili(seconds*60):
  game.vfx._process(1.0/60);game.vfx.spectacle._process(1.0/60)
  game.player.animate(1.0/60,false)
  for actor in game.enemies:actor.animate(1.0/60,false)
  if projectiles:game._update_technique(1.0/60)
  await create_timer(1.0/60).timeout
func fresh(character:String="atlas"):
 game._clear_combat();game.player.set_character(character);game.player.position=Vector3.ZERO
 game.mode="playing";game.growth={"skill_level":1};game.damage=20;game.hp=110;game.max_hp=110
 game.run_mode="sprint";game.wave=3;game.stage=0;game.arena.set_stage(0)
 game.hud.playing()
func target(at:Vector3,role:String="rookie"):
 var actor=game._spawn(at,role);actor.max_health=10000;actor.health=10000;return actor
func run():
 DirAccess.make_dir_recursive_absolute(FOLDER)
 root.size=Vector2i(540,960)
 root.get_node("MobileCore").save=CoreSaveStore.new("user://ranged-capture.json")
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
 process_frame.connect(func():
  if game.mode=="paused":game.resume_run()
 )
 game.vfx.set_process(false);game.vfx.spectacle.set_process(false)
 game.start_run();fresh();game.technique_id="quake"
 for i in 6:
  var a:=i*TAU/6;target(Vector3(cos(a)*2.8,0,sin(a)*2.8),"brute" if i%2 else "rookie")
 await tick(.3);game._cast_move("quake",1);await tick(.16);snap("quake-burst")
 await tick(.25);snap("quake-debris")
 fresh()
 target(Vector3(-2.5,0,-1.5),"drone");target(Vector3(-.8,0,-2.6),"spitter")
 target(Vector3(1.2,0,-2.8),"hound");target(Vector3(3,0,-1.1),"wisp")
 await tick(.3);snap("creature-silhouettes")
 for id in ["aegis","ion","onyx"]:
  fresh(id);target(Vector3(0,0,-4),"spitter");target(Vector3(.6,0,-4.5),"drone")
  await tick(.2);game._attack();await tick(.12,true);snap("weapon-"+id)
 for id in ["pulse","orb","thunder","cyclone"]:
  fresh();game.technique_id=id;target(Vector3(0,0,-4),"drone");target(Vector3(1,0,-4.3),"wisp")
  game._cast_move(id,1);await tick(.15,true);snap("skill-"+id)
 fresh();root.size=Vector2i(320,568);target(Vector3(0,0,-3.3),"drone")
 await tick(.2)
 var actor=game.enemies[0];actor.attack_target=game.player.position;actor.windup=.01;game._update_enemy(actor,.02)
 await tick(.1,true);snap("small-hostile-shot")
 game.go_home();game.request_quit()
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://ranged-capture.json"+suffix)
