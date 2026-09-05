extends SceneTree
var game:Node3D
const FOLDER="res://docs/refinement-preview/"
func _initialize():call_deferred("run")
func snap(name:String,delay:float=.3):
 await create_timer(delay).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(FOLDER+name+".png")
func run():
 DirAccess.make_dir_recursive_absolute(FOLDER)
 var core:=root.get_node("MobileCore")
 core.save=CoreSaveStore.new("user://refinement-capture.json")
 core.save.data.coins=2400;core.save.data.progress.unlocked_stage=4
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 game.set_physics_process(false)
 for resolution in [Vector2i(540,960),Vector2i(320,568),Vector2i(768,1024)]:
  root.size=resolution
  var prefix:String="phone" if resolution.x==540 else ("small" if resolution.x==320 else "tablet")
  game.go_home();await snap(prefix+"-home")
  game.hud.training();await snap(prefix+"-gym")
  game.hud.shop();await snap(prefix+"-shop")
  game.go_home();game.hud.circuits();game.hud.cycle_venue(1);await snap(prefix+"-fight")
  game.stage=1;game.start_run();game.set_physics_process(false)
  game.level=3;game.combo=8;game.hud.update_stats()
  for i in 7:
   var enemy=game._spawn(Vector3(cos(i*TAU/7)*3.4,0,sin(i*TAU/7)*3.4),["rookie","runner","brute","spark","charger","guard","boss"][i])
   enemy.animate(.15,true)
  game.hud.toast("WAVE 3 CLEAR  /  RECOVERY +7 HP")
  await snap(prefix+"-clear")
  game.mode="upgrade";game.options=[RushBalance.ability("frost"),RushBalance.ability("armor"),RushBalance.ability("range")]
  game.hud.abilities(game.options);await snap(prefix+"-upgrade")
  game.hud._remove_upgrade();game.mode="playing";game.hud.playing()
  if prefix=="phone":
   core.save.data.settings.effects=false;game.apply_settings()
   for entry in RushRoster.MOVES:
    game.vfx.clear();game.barrage_time=0;game.cyclone_clock=0;game.projectile_time=0
    for enemy in game.enemies:enemy.health=100000
    game._cast_move(entry.id,1)
    game._update_technique(.16)
    game.player.animate(.16,false)
    await snap("skill-"+entry.id,.10)
  game.finish_run(false)
 game.queue_free();await process_frame
 await create_timer(.3).timeout
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://refinement-capture.json"+suffix)
 quit()
