extends SceneTree
var game:Node3D
const FOLDER="res://docs/playtest-preview/"
func _initialize():call_deferred("run")
func snap(name:String,delay:float=.3):
 await create_timer(delay).timeout;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(FOLDER+name+".png")
func run():
 DirAccess.make_dir_recursive_absolute(FOLDER)
 var core:=root.get_node("MobileCore");core.save=CoreSaveStore.new("user://playtest-capture.json")
 core.save.data.coins=2499;core.save.data.progress.unlocked_stage=4
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
 for resolution in [Vector2i(540,960),Vector2i(320,568),Vector2i(768,1024)]:
  root.size=resolution
  var prefix:String="phone" if resolution.x==540 else ("small" if resolution.x==320 else "tablet")
  game.go_home();await snap(prefix+"-home")
  game.hud.fighter_index=7;game.hud.fighters(true);await snap(prefix+"-fighter")
  game.hud.training();await snap(prefix+"-gym")
  game.hud.shop();await snap(prefix+"-shop")
  game.go_home();game.hud.circuits();game.hud.select_challenge("hell");await snap(prefix+"-fight")
  game.start_run();game.set_physics_process(false)
  for i in 8:
   var enemy=game._spawn(Vector3(cos(i*TAU/8)*3,0,sin(i*TAU/8)*3),["bone","hexer","revenant","brute"][i%4]);enemy.animate(.22,true)
  await snap(prefix+"-creatures")
  game.mode="upgrade";game.options=[RushBalance.ability("frost"),RushBalance.ability("burn"),RushBalance.ability("leech")]
  game.hud.abilities(game.options);await snap(prefix+"-upgrade")
  game.hud._remove_upgrade();game.mode="playing";game.finish_run(false)
 if true:
  root.size=Vector2i(540,960);game.go_home()
  for index in [6,7,8]:game.hud.fighter_index=index;game.hud.fighters(true);await snap("hero-"+game.player.character_id)
 game.queue_free();await process_frame;await create_timer(.5).timeout
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://playtest-capture.json"+suffix)
 quit()
