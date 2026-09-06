extends SceneTree
const FOLDER="res://docs/boss-preview/"
var game:Node3D
func _initialize():call_deferred("run")
func snap(name:String):
 game.hud.update_stats()
 await create_timer(.12).timeout
 RenderingServer.force_draw();root.get_texture().get_image().save_png(FOLDER+name+".png")
func run():
 DirAccess.make_dir_recursive_absolute(FOLDER)
 root.size=Vector2i(540,960)
 var core:=root.get_node("MobileCore");core.save=CoreSaveStore.new("user://boss-capture.json")
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
 process_frame.connect(func():
  if game.mode=="paused":game.resume_run()
 )
 game.run_mode="bossrush";game.start_run();game._clear_combat();game.wave=1;game.hp=55;game.special_charge=60;game.technique_id="quake";game.hud.playing()
 var actor=game._spawn(Vector3(0,0,-1.6),"boss");game.boss=actor
 actor.max_health=3000;actor.health=1450;actor.encounter.phase=2
 actor.encounter._begin(game,actor,"slam");actor.encounter.windup=.34
 game._update_enemy(actor,.01)
 await snap("phase-two-break")
 root.size=Vector2i(320,568);await snap("small-break")
 root.size=Vector2i(768,1024);await snap("tablet-break")
 root.size=Vector2i(540,960);game.technique();await snap("skill-break")
 actor.encounter=RushBossCombat.new();actor.encounter.phase=2
 actor.encounter._begin(game,actor,"slam");actor.encounter.windup=.23
 game.dash();await snap("counter-ready")
 game._attack();await snap("counter-hit")
 game.go_home();game.request_quit()
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://boss-capture.json"+suffix)
