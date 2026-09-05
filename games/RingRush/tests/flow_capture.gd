extends SceneTree
var game:Node3D
const FOLDER="res://docs/flow-preview/"
func _initialize():call_deferred("run")
func snap(name:String,delay:float=.3):
 await create_timer(delay).timeout
 RenderingServer.force_draw()
 root.get_texture().get_image().save_png(FOLDER+name+".png")
func run():
 DirAccess.make_dir_recursive_absolute(FOLDER)
 var core:=root.get_node("MobileCore");core.save=CoreSaveStore.new("user://flow-capture.json")
 core.save.data.coins=2400;core.save.data.progress.unlocked_stage=4
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
 for resolution in [Vector2i(540,960),Vector2i(320,568),Vector2i(768,1024)]:
  root.size=resolution
  var prefix:String="phone" if resolution.x==540 else ("small" if resolution.x==320 else "tablet")
  game.go_home();await snap(prefix+"-home")
  game.hud.shop();await snap(prefix+"-shop")
  game.hud.training();await snap(prefix+"-gym")
  game.go_home();game.hud.circuits();game.hud.select_challenge("survival30");await snap(prefix+"-fight")
  game.hud.select_challenge("rift");await snap(prefix+"-secret")
  game.go_home();game.demo_move("quake");await snap(prefix+"-demo",.13)
  game.hud.moves(true);game.go_home()
 root.size=Vector2i(540,960)
 for i in RushRoster.CHARACTERS.size():
  game.hud.fighter_index=i;game.hud.fighters(true);await snap("fighter-"+game.player.character_id)
 for move in ["barrage","meteor","thunder"]:
  game.demo_move(move);await snap("demo-"+move,.14);game.hud.moves(true)
 game.go_home();RushChallenges.unlock_rift(core.save);game.run_mode="rift";game.start_run();game.set_physics_process(false)
 for i in 10:
  var e=game._spawn(Vector3(cos(i*TAU/10)*3.5,0,sin(i*TAU/10)*3.5),["bone","revenant","hexer"][i%3]);e.animate(.2,true)
 game._spawn_boss();await snap("rift-combat")
 game.mode="upgrade";game.options=[RushBalance.ability("frost"),RushBalance.ability("burn"),RushBalance.ability("leech")]
 game.hud.abilities(game.options);await snap("rift-upgrade")
 game.queue_free();await process_frame;await create_timer(.5).timeout
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute("user://flow-capture.json"+suffix)
 quit()
